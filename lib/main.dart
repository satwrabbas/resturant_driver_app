import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<void> updateOrderStatus(String id, String newStatus) async {
    await supabase.from('orders').update({'status': newStatus}).eq('id', id);
    
    // رسالة تأكيد
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

  // تصميم كارت المهمة
  Widget _buildTaskCard(Map<String, dynamic> task) {
    bool isOnWay = task['status'] == 'on_way';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // تغيير لون الحدود حسب الحالة
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: isOnWay ? Colors.blue : Colors.green, 
              width: 6
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الهيدر: رقم الطلب والحالة
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
              
              // التفاصيل
              _buildInfoRow(Icons.location_on, 'العنوان:', task['delivery_address'] ?? 'غير محدد'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.attach_money, 'المبلغ المطلوب:', '${task['grand_total']} ر.س'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, 'وقت الطلب:', task['created_at'].toString().substring(11, 16)),

              const SizedBox(height: 20),

              // الزر الكبير
              SizedBox(
                width: double.infinity,
                height: 50,
                child: isOnWay
                    ? ElevatedButton.icon(
                        onPressed: () => updateOrderStatus(task['id'], 'delivered'),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('تم التسليم للعميل (إنهاء)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => updateOrderStatus(task['id'], 'on_way'),
                        icon: const Icon(Icons.touch_app),
                        label: const Text('قبول واستلام الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
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