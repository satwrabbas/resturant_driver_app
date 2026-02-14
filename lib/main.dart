import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔴 ضع مفاتيح مشروعك هنا (نفس المفاتيح السابقة)
  await Supabase.initialize(
    url: 'https://fxifvbeaovnellxxsydj.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4aWZ2YmVhb3ZuZWxseHhzeWRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0NTIyMTYsImV4cCI6MjA4NjAyODIxNn0.7QNTPeHcKqyHNWdaIsgylt41CJC-ExBPX3QgxXN1HLY',
  );

  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق السائق',
      theme: ThemeData(
        // استخدام اللون الأزرق لتمييزه عن تطبيق العميل الأحمر
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const DriverHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTasks();
    setupRealtimeSubscription();
  }

  
  // --- 🗺️ دالة فتح الخرائط (تمت إضافتها هنا) ---
  Future<void> openMap(double lat, double lng) async {
    // رابط خرائط جوجل للملاحة
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    
    // رابط عام (يعمل على الآيفون أيضاً)
    final Uri appleMapsUrl = Uri.parse("https://maps.apple.com/?daddr=$lat,$lng");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl);
      } else {
        // إذا فشل، نفتح الرابط في المتصفح
        final Uri webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن فتح الخرائط: $e')),
        );
      }
    }
  }
  // ---------------------------------------------
  
  // جلب المهام (الطلبات الجاهزة + التي بحوزة السائق)
  Future<void> fetchTasks() async {
    try {
      final response = await supabase
          .from('orders')
          .select('*')
          // نريد الطلبات الجاهزة للاستلام OR التي يوصلها السائق حالياً
          .or('status.eq.ready_for_pickup,status.eq.on_way')
          .order('created_at', ascending: false);

      setState(() {
        tasks = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  // الاستماع للتحديثات الحية
  void setupRealtimeSubscription() {
    supabase
        .channel('driver_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            // عند حدوث أي تغيير في الطلبات، نحدث القائمة
            fetchTasks();
          },
        )
        .subscribe();
  }

  // تغيير حالة الطلب
  // تغيير حالة الطلب
  Future<void> updateOrderStatus(String id, String newStatus) async {
    try {
      // 1. تحديث قاعدة البيانات
      await supabase.from('orders').update({'status': newStatus}).eq('id', id);

      // 2. تحديث الواجهة فوراً (بدون انتظار إعادة التحميل من السيرفر)
      setState(() {
        if (newStatus == 'delivered') {
          // إذا تم التسليم، نحذف الطلب من القائمة لأنه انتهى
          tasks.removeWhere((task) => task['id'] == id);
        } else {
          // إذا تحول إلى "جاري التوصيل"، نحدث حالته داخل القائمة ليتحول الزر واللون
          final index = tasks.indexWhere((task) => task['id'] == id);
          if (index != -1) {
            tasks[index]['status'] = newStatus;
          }
        }
      });

      // 3. رسالة تأكيد
      if (mounted) {
        String message = newStatus == 'on_way'
            ? 'تم استلام الطلب! انطلق للعميل 🛵'
            : 'تم توصيل الطلب بنجاح! 💵';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: newStatus == 'on_way' ? Colors.blue : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // في حال حدوث خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحديث: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_motorsports_outlined),
            SizedBox(width: 10),
            Text('كابتن التوصيل'),
          ],
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: fetchTasks,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : tasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(tasks[index]);
                    },
                  ),
      ),
    );
  }

  // واجهة عند عدم وجود طلبات

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات جاهزة حالياً',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text('استرح قليلاً بانتظار تجهيز المطعم للطلبات'),
        ],
      ),
    );
  }


Widget _buildTaskCard(Map<String, dynamic> task) {
    bool isOnWay = task['status'] == 'on_way';

    // 🔍 طباعة للتأكد (ستظهر في الـ Console بالأسفل)
    print("Checking Task #${task['id']}: lat=${task['lat']}, latitude=${task['latitude']}");

    // 1. محاولة جلب البيانات سواء كان اسمها (latitude) أو (lat)
    var rawLat = task['latitude'] ?? task['lat'];
    var rawLng = task['longitude'] ?? task['lng'];

    // 2. دالة صغيرة لتحويل البيانات إلى رقم (Double) بأمان
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble(); // إذا كان رقماً
      if (value is String) return double.tryParse(value); // إذا كان نصاً
      return null;
    }

    double? lat = parseCoord(rawLat);
    double? lng = parseCoord(rawLng);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: isOnWay ? Colors.blue : Colors.green, width: 6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رقم الطلب وشارة الحالة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${task['id'].toString().substring(0, 5)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOnWay ? Colors.blue[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isOnWay ? Colors.blue : Colors.green),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOnWay ? Icons.directions_bike : Icons.store,
                          size: 16,
                          color: isOnWay ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnWay ? 'جاري التوصيل' : 'جاهز بالمطعم',
                          style: TextStyle(
                            color: isOnWay ? Colors.blue[800] : Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 25),

              // العنوان
              _buildInfoRow(Icons.location_on, 'العنوان:', task['delivery_address'] ?? 'غير محدد'),

              // 👇👇 منطق عرض الزر (معدل) 👇👇
              if (lat != null && lng != null) ...[
                // إذا وجدت الإحداثيات اعرض الزر
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: InkWell(
                    onTap: () => openMap(lat, lng),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 24, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            "فتح الموقع على الخريطة 🗺️",
                            style: TextStyle(
                              color: Colors.blue, 
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // 🔴 (اختياري) رسالة تظهر فقط إذا لم توجد إحداثيات لمعرفة السبب
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "⚠️ لا يوجد موقع جغرافي لهذا الطلب",
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                ),
              ],
              
              const SizedBox(height: 5),
              _buildInfoRow(Icons.attach_money, 'المبلغ:', '${task['grand_total']} ر.س'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, 'الوقت:', task['created_at'].toString().substring(11, 16)),

              const SizedBox(height: 20),

              // زر الإجراء الرئيسي
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => updateOrderStatus(task['id'], isOnWay ? 'delivered' : 'on_way'),
                  icon: Icon(isOnWay ? Icons.check_circle : Icons.touch_app),
                  label: Text(isOnWay ? 'تم التسليم' : 'استلام الطلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnWay ? Colors.green : Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}