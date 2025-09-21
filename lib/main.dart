import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// =================================================================
// 1. MODELS & DATA SERVICE
// =================================================================
class InventoryItem {
  String id;
  String name;
  double quantity;
  String unit;

  InventoryItem({required this.id, required this.name, required this.quantity, required this.unit});

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        quantity: json['quantity'],
        unit: json['unit'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'quantity': quantity, 'unit': unit};
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
        return itemsJson.map((json) => InventoryItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> saveItems(List<InventoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsString = jsonEncode(items.map((item) => item.toJson()).toList());
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
        _totalQuantity = items.fold(0, (sum, item) => sum + item.quantity);
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
                Text(_totalUniqueItems.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                Text('نوع کالا', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.deepPurple.withOpacity(0.2)),
            Column(
              children: [
                Text(_totalQuantity.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                Text('موجودی کل', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardActionCard(BuildContext context,
      {required IconData icon, required String label, required String description, required Color color, required VoidCallback onTap}) {
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

  Future<void> _addItemToCart() async {
    List<InventoryItem> availableItems = await _service.loadItems();
    availableItems.removeWhere((item) => item.quantity <= 0);
    if (!mounted) return;
    InventoryItem? selectedItem = await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => _SelectItemSheet(items: availableItems));
    if (selectedItem != null) {
      if (!mounted) return;
      _promptForQuantity(selectedItem);
    }
  }

  void _promptForQuantity(InventoryItem item) {
    final quantityController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('مقدار فروش: ${item.name}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('موجودی انبار: ${item.quantity} ${item.unit}'),
              const SizedBox(height: 16),
              TextField(
                  controller: quantityController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'تعداد/مقدار'))
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
              FilledButton(
                  onPressed: () {
                    final qty = double.tryParse(quantityController.text);
                    if (qty != null && qty > 0 && qty <= item.quantity) {
                      setState(() {
                        var existingIndex =
                            _salesCart.indexWhere((cartItem) => cartItem.inventoryItem.id == item.id);
                        if (existingIndex != -1) {
                          _salesCart[existingIndex].quantityToSell = qty;
                        } else {
                          _salesCart.add(SalesCartItem(inventoryItem: item, quantityToSell: qty));
                        }
                      });
                      Navigator.pop(context);
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('مقدار وارد شده نامعتبر است.'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('افزودن به لیست'))
            ]));
  }

  Future<void> _finalizeSale() async {
    if (_salesCart.isEmpty) return;
    HapticFeedback.heavyImpact();
    List<InventoryItem> allItems = await _service.loadItems();
    for (var cartItem in _salesCart) {
      var itemInStock = allItems.firstWhere((item) => item.id == cartItem.inventoryItem.id);
      itemInStock.quantity -= cartItem.quantityToSell;
    }
    await _service.saveItems(allItems);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فروش با موفقیت نهایی شد.'), backgroundColor: Colors.green));
    setState(() => _salesCart.clear());
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
                    ? _buildEmptyState('سبد فروش خالی است', Icons.shopping_cart_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 5, bottom: 100),
                        itemCount: _salesCart.length,
                        itemBuilder: (context, index) {
                          final cartItem = _salesCart[index];
                          return Card(
                              child: ListTile(
                                  leading: const Icon(Icons.shopping_basket_outlined, color: Colors.cyan),
                                  title: Text(cartItem.inventoryItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('تعداد فروش: ${cartItem.quantityToSell} ${cartItem.inventoryItem.unit}'),
                                  trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => setState(() => _salesCart.removeAt(index)))));
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
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _addItemToCart,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('افزودن کالا'),
          backgroundColor: Colors.cyan,
          foregroundColor: Colors.white),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey))
    ]));
  }
}

class _SelectItemSheet extends StatelessWidget {
  final List<InventoryItem> items;
  const _SelectItemSheet({required this.items});
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('یک کالا برای فروش انتخاب کنید', style: Theme.of(context).textTheme.titleLarge)),
          Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('کالایی برای فروش در انبار موجود نیست.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                            title: Text(item.name),
                            subtitle: Text('موجودی: ${item.quantity} ${item.unit}'),
                            onTap: () => Navigator.pop(context, item));
                      }))
        ]));
  }
}

// =================================================================
// 5. INVENTORY MANAGEMENT PAGES
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
    var loadedItems = await _service.loadItems();
    if (mounted) {
      setState(() {
        _items = loadedItems;
        _isLoading = false;
      });
    }
  }

  void _navigateToAddEditPage({InventoryItem? item, int? index}) async {
    final result = await Navigator.push<InventoryItem>(
        context, MaterialPageRoute(builder: (context) => AddEditItemPage(item: item)));
    if (result != null) {
      setState(() {
        if (item != null && index != null) {
          // Edit
          _items[index] = result;
        } else {
          // Add
          _items.insert(0, result);
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
        }
      });
      _service.saveItems(_items);
    }
  }

  void _deleteItem(InventoryItem item, int index) {
    final removedItem = _items.removeAt(index);
    _listKey.currentState?.removeItem(index, (context, animation) => _buildRemovedItem(removedItem, animation),
        duration: const Duration(milliseconds: 400));
    _service.saveItems(_items);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} حذف شد.'), backgroundColor: Colors.redAccent));
  }

  Widget _buildRemovedItem(InventoryItem item, Animation<double> animation) {
    return SizeTransition(
        sizeFactor: animation, child: Opacity(opacity: 0, child: Card(child: ListTile(title: Text(item.name)))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت انبار')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _buildEmptyState('انباری خالی است', Icons.inventory_2_outlined)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: AnimatedList(
                        key: _listKey,
                        initialItemCount: _items.length,
                        padding: const EdgeInsets.only(top: 5, bottom: 80),
                        itemBuilder: (context, index, animation) {
                          final item = _items[index];
                          return SizeTransition(
                              sizeFactor: animation,
                              child: Slidable(
                                  key: ValueKey(item.id),
                                  startActionPane: ActionPane(motion: const DrawerMotion(), children: [
                                    SlidableAction(
                                        onPressed: (_) => _deleteItem(item, index),
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete_sweep_outlined,
                                        label: 'حذف'),
                                    SlidableAction(
                                        onPressed: (_) => _navigateToAddEditPage(item: item, index: index),
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
                                                  fontWeight: item.quantity < 5 ? FontWeight.bold : null))))));
                        })),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToAddEditPage(),
          tooltip: 'افزودن کالای جدید',
          child: const Icon(Icons.add_rounded)),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: () => _navigateToAddEditPage(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('افزودن اولین کالا'))
    ]));
  }
}

class AddEditItemPage extends StatefulWidget {
  final InventoryItem? item;
  const AddEditItemPage({super.key, this.item});
  @override
  State<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends State<AddEditItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late String _selectedUnit;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.item != null;
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '');
    _selectedUnit = widget.item?.unit ?? 'عدد';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      final newItem = InventoryItem(
        id: _isEditing ? widget.item!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
      );
      Navigator.pop(context, newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش کالا' : 'افزودن کالا'),
        actions: [IconButton(icon: const Icon(Icons.check_rounded), onPressed: _saveForm, tooltip: 'ذخیره')],
      ),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(16.0), children: [
                TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'نام کالا', prefixIcon: Icon(Icons.label_outline_rounded)),
                    validator: (value) => value == null || value.isEmpty ? 'نام کالا نمی‌تواند خالی باشد' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'مقدار', prefixIcon: Icon(Icons.format_list_numbered_rounded)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        (value == null || value.isEmpty || double.tryParse(value) == null) ? 'مقدار نامعتبر است' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'واحد', prefixIcon: Icon(Icons.straighten_rounded)),
                    items: ['عدد', 'متر'].map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedUnit = value);
                    }),
                const SizedBox(height: 32),
                FilledButton(onPressed: _saveForm, child: const Text('ذخیره تغییرات'))
              ]))),
    );
  }
}
