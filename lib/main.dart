import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/rendering.dart';

// =================================================================
// 1. MODELS & DATA SERVICE
// =================================================================
class InventoryItem {
  String id;
  String name;
  double quantity;
  String unit;
  String code;

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.code,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'],
        code: json['code'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'code': code,
      };
}

class SalesCartItem {
  final InventoryItem inventoryItem;
  double quantityToSell;
  SalesCartItem({required this.inventoryItem, required this.quantityToSell});
}

class InventoryService {
  static const _key = 'inventory_items';

  Future<List<InventoryItem>> loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? itemsString = prefs.getString(_key);
      if (itemsString != null) {
        final List<dynamic> itemsJson = jsonDecode(itemsString);
        return itemsJson.map((e) => InventoryItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> saveItems(List<InventoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsString = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, itemsString);
  }
}

// =================================================================
// 2. MAIN APP & THEME
// =================================================================
void main() => runApp(const InventoryApp());

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'انباردار حرفه‌ای',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.cyan,
          background: Colors.grey[50],
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

// =================================================================
// 3. HOME PAGE (DASHBOARD)
// =================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _totalUniqueItems = 0;
  double _totalQuantity = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final items = await InventoryService().loadItems();
    if (mounted) {
      setState(() {
        _totalUniqueItems = items.length;
        _totalQuantity = items.fold(0.0, (sum, item) => sum + item.quantity);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade500],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.storefront_rounded, size: 30, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 16),
                      Text('انباردار حرفه‌ای',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('کسب و کار خود را هوشمندانه مدیریت کنید',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildStatsCard(),
                          const SizedBox(height: 24),
                          _buildDashboardActionCard(
                            context,
                            icon: Icons.point_of_sale_rounded,
                            label: 'ثبت فروش جدید',
                            description: 'ثبت فاکتور و کسر از موجودی',
                            color: Colors.cyan,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesPage()))
                                .then((_) => _loadStats()),
                          ),
                          const SizedBox(height: 16),
                          _buildDashboardActionCard(
                            context,
                            icon: Icons.inventory_2_rounded,
                            label: 'مدیریت انبار',
                            description: 'افزودن، ویرایش و حذف کالاها',
                            color: Colors.orange,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryListPage()))
                                .then((_) => _loadStats()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 0,
      color: Colors.deepPurple.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(_totalUniqueItems.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                Text('نوع کالا', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.deepPurple.withOpacity(0.2)),
            Column(
              children: [
                Text(_totalQuantity.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                Text('موجودی کل', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

// =================================================================
// 4. SALES PAGE
// =================================================================
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final InventoryService _service = InventoryService();
  List<SalesCartItem> _salesCart = [];
  List<InventoryItem> _allItems = [];

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  Future<void> _loadAllItems() async {
    _allItems = await _service.loadItems();
  }

  Future<void> _addItemToCartManually() async {
    List<InventoryItem> available = _allItems.where((i) => i.quantity > 0).toList();
    if (!mounted) return;
    final selected = await showModalBottomSheet<InventoryItem>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _SelectItemSheet(items: available));
    if (selected != null) _promptForQuantity(selected);
  }

  void _promptForQuantity(InventoryItem item) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('مقدار فروش: ${item.name}'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('موجودی انبار: ${item.quantity} ${item.unit}'),
                const SizedBox(height: 16),
                TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'تعداد/مقدار')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                FilledButton(
                    onPressed: () {
                      final qty = double.tryParse(controller.text);
                      if (qty != null && qty > 0 && qty <= item.quantity) {
                        setState(() {
                          final idx = _salesCart.indexWhere((c) => c.inventoryItem.id == item.id);
                          if (idx != -1) {
                            _salesCart[idx].quantityToSell = qty;
                          } else {
                            _salesCart.add(SalesCartItem(inventoryItem: item, quantityToSell: qty));
                          }
                        });
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('مقدار نامعتبر'), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('افزودن به لیست'))
              ],
            ));
  }

  Future<void> _finalizeSale() async {
    if (_salesCart.isEmpty) return;
    HapticFeedback.heavyImpact();
    final all = await _service.loadItems();
    for (final c in _salesCart) {
      final stock = all.firstWhere((i) => i.id == c.inventoryItem.id);
      stock.quantity -= c.quantityToSell;
    }
    await _service.saveItems(all);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فروش نهایی شد'), backgroundColor: Colors.green));
    setState(() {
      _salesCart.clear();
      _loadAllItems();
    });
  }

  void _scanQRCode() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('اسکن QR Code')),
                  body: Directionality(
                    textDirection: TextDirection.rtl,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.firstOrNull?.rawValue;
                        if (barcode == null) return;
                        final item = _allItems.cast<InventoryItem?>().firstWhere((i) => i?.code == barcode, orElse: () => null);
                        if (item != null) {
                          Navigator.pop(context);
                          _promptForQuantity(item);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('کالا پیدا نشد'), backgroundColor: Colors.red));
                        }
                      },
                    ),
                  ),
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت فاکتور فروش')),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            Expanded(
                child: _salesCart.isEmpty
                    ? _buildEmptyState('سبد خالی است', Icons.shopping_cart_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 5, bottom: 100),
                        itemCount: _salesCart.length,
                        itemBuilder: (_, i) {
                          final c = _salesCart[i];
                          return Card(
                              child: ListTile(
                                  leading: const Icon(Icons.shopping_basket_outlined, color: Colors.cyan),
                                  title: Text(c.inventoryItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('تعداد: ${c.quantityToSell} ${c.inventoryItem.unit}'),
                                  trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => setState(() => _salesCart.removeAt(i)))));
                        })),
            if (_salesCart.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          onPressed: _finalizeSale,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('نهایی کردن فروش'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green))))
          ])),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
              onPressed: _addItemToCartManually,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('افزودن کالا'),
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
              onPressed: _scanQRCode,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('اسکن QR Code'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(msg, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey))
      ]));
}

// =================================================================
// 5. INVENTORY LIST + QR DIALOG
// =================================================================
class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});
  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final InventoryService _service = InventoryService();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<InventoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final loaded = await _service.loadItems();
    if (mounted) {
      setState(() {
        _items = loaded;
        _isLoading = false;
      });
    }
  }

  void _navigateToAddEdit({InventoryItem? item, int? index}) async {
    final result = await Navigator.push<InventoryItem>(
        context, MaterialPageRoute(builder: (_) => AddEditItemPage(item: item)));
    if (result != null) {
      setState(() {
        if (item != null && index != null) {
          _items[index] = result;
        } else {
          _items.insert(0, result);
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
        }
      });
      _service.saveItems(_items);
    }
  }

  void _deleteItem(InventoryItem item, int index) {
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
        index, (_, anim) => _buildRemovedItem(removed, anim), duration: const Duration(milliseconds: 400));
    _service.saveItems(_items);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} حذف شد'), backgroundColor: Colors.redAccent));
  }

  Widget _buildRemovedItem(InventoryItem item, Animation<double> anim) =>
      SizeTransition(sizeFactor: anim, child: Opacity(opacity: 0, child: Card(child: ListTile(title: Text(item.name)))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت انبار')),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _buildEmptyState('انبار خالی است', Icons.inventory_2_outlined)
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: AnimatedList(
                          key: _listKey,
                          initialItemCount: _items.length,
                          padding: const EdgeInsets.only(top: 5, bottom: 80),
                          itemBuilder: (_, i, anim) {
                            final item = _items[i];
                            return SizeTransition(
                                sizeFactor: anim,
                                child: Slidable(
                                    key: ValueKey(item.id),
                                    startActionPane: ActionPane(motion: const DrawerMotion(), children: [
                                      SlidableAction(
                                          onPressed: (_) => _deleteItem(item, i),
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          icon: Icons.delete_sweep_outlined,
                                          label: 'حذف'),
                                      SlidableAction(
                                          onPressed: (_) => _navigateToAddEdit(item: item, index: i),
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          icon: Icons.edit_outlined,
                                          label: 'ویرایش')
                                    ]),
                                    child: Card(
                                        child: ListTile(
                                            leading: CircleAvatar(
                                                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                                                foregroundColor: Colors.deepPurple,
                                                child: const Icon(Icons.widgets_outlined)),
                                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text('موجودی: ${item.quantity} ${item.unit}',
                                                style: TextStyle(
                                                    color: item.quantity < 5 ? Colors.orange.shade700 : null,
                                                    fontWeight: item.quantity < 5 ? FontWeight.bold : null)),
                                            trailing: IconButton(
                                                icon: const Icon(Icons.qr_code_rounded, color: Colors.deepPurple),
                                                onPressed: () => showDialog(
                                                      context: context,
                                                      builder: (_) => QrDownloadDialog(item: item),
                                                    ))))));
                          }))),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToAddEdit(),
          tooltip: 'افزودن کالا',
          child: const Icon(Icons.add_rounded)),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(msg, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: () => _navigateToAddEdit(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن اولین کالا'))
      ]));
}

// =================================================================
// 6. QR DOWNLOAD DIALOG (اصلاح شده — صفحه سیاه رفع شد)
// =================================================================
class QrDownloadDialog extends StatefulWidget {
  final InventoryItem item;
  const QrDownloadDialog({super.key, required this.item});

  @override
  State<QrDownloadDialog> createState() => _QrDownloadDialogState();
}

class _QrDownloadDialogState extends State<QrDownloadDialog> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _saveQr() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دسترسی به گالری رد شد'), backgroundColor: Colors.red));
        return;
      }

      final result = await ImageGallerySaver.saveImage(pngBytes, name: 'qr_${widget.item.name}');
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code ذخیره شد'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('QR Code: ${widget.item.name}', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 220,
              height: 220,
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: widget.item.code,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveQr,
            icon: const Icon(Icons.download_rounded),
            label: const Text('دانلود QR Code'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))
      ],
    );
  }
}

// =================================================================
// 7. ADD / EDIT ITEM PAGE
// =================================================================
class AddEditItemPage extends StatefulWidget {
  final InventoryItem? item;
  const AddEditItemPage({super.key, this.item});

  @override
  State<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends State<AddEditItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _codeCtrl;
  late String _unit;
  late bool _editing;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _editing = widget.item != null;
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _qtyCtrl = TextEditingController(text: widget.item?.quantity.toString() ?? '');
    _codeCtrl = TextEditingController(text: widget.item?.code ?? '');
    _unit = widget.item?.unit ?? 'عدد';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      final newItem = InventoryItem(
        id: _editing ? widget.item!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text,
        quantity: double.parse(_qtyCtrl.text),
        unit: _unit,
        code: _codeCtrl.text,
      );
      Navigator.pop(context, newItem);
    }
  }

  Future<void> _saveQr() async {
    if (_codeCtrl.text.isEmpty) return;
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دسترسی به گالری رد شد'), backgroundColor: Colors.red));
        return;
      }

      final result = await ImageGallerySaver.saveImage(pngBytes, name: 'qr_${_nameCtrl.text}');
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code ذخیره شد'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'ویرایش کالا' : 'افزودن کالا'),
        actions: [IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save, tooltip: 'ذخیره')],
      ),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'نام کالا', prefixIcon: Icon(Icons.label_outline_rounded)),
                    validator: (v) => v?.isEmpty ?? true ? 'نام الزامی است' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(labelText: 'مقدار', prefixIcon: Icon(Icons.format_list_numbered_rounded)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v?.isEmpty ?? true) || double.tryParse(v!) == null ? 'مقدار نامعتبر' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: 'کد محصول', prefixIcon: Icon(Icons.code_rounded)),
                    validator: (v) => v?.isEmpty ?? true ? 'کد الزامی است' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(labelText: 'واحد', prefixIcon: Icon(Icons.straighten_rounded)),
                    items: ['عدد', 'متر'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _unit = v!)),
                const SizedBox(height: 32),
                if (_codeCtrl.text.isNotEmpty)
                  Column(
                    children: [
                      Center(
                        child: RepaintBoundary(
                          key: _qrKey,
                          child: Container(
                            width: 220,
                            height: 220,
                            color: Colors.white,
                            padding: const EdgeInsets.all(10),
                            child: QrImageView(
                              data: _codeCtrl.text,
                              version: QrVersions.auto,
                              size: 200,
                              gapless: false,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saveQr,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('دانلود QR Code'),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                FilledButton(onPressed: _save, child: const Text('ذخیره تغییرات'))
              ]))),
    );
  }
}

// =================================================================
// 8. SELECT ITEM SHEET
// =================================================================
class _SelectItemSheet extends StatelessWidget {
  final List<InventoryItem> items;
  const _SelectItemSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('یک کالا برای فروش انتخاب کنید', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('کالایی موجود نیست'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return ListTile(
                            title: Text(it.name),
                            subtitle: Text('موجودی: ${it.quantity} ${it.unit}'),
                            onTap: () => Navigator.pop(context, it));
                      }))
        ]));
  }
}
