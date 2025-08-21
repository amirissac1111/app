



import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Helper Functions & Models ---
IconData _getIconForUnit(String unit) {
  switch (unit) {
    case 'متر': return Icons.square_foot_rounded;
    case 'عدد': return Icons.push_pin_rounded;
    case 'خدمات': return Icons.design_services_rounded;
    case 'متر مربع': return Icons.aspect_ratio_rounded;
    case 'قواره': return Icons.view_quilt_rounded;
    default: return Icons.sell_rounded;
  }
}

String _persianToEnglishNumbers(String input) {
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(persian[i], english[i]).replaceAll(arabic[i], english[i]);
  }
  return input;
}

String _numberToPersianWords(int number) {
  if (number == 0) return 'صفر';

  final List<String> yekan = ["", "یک", "دو", "سه", "چهار", "پنج", "شش", "هفت", "هشت", "نه"];
  final List<String> dahgan = ["", "", "بیست", "سی", "چهل", "پنجاه", "شصت", "هفتاد", "هشتاد", "نود"];
  final List<String> dahyek = ["ده", "یازده", "دوازده", "سیزده", "چهارده", "پانزده", "شانزده", "هفده", "هجده", "نوزده"];
  final List<String> sadgan = ["", "یکصد", "دویست", "سیصد", "چهارصد", "پانصد", "ششصد", "هفتصد", "هشتصد", "نهصد"];
  final List<String> basex = ["", "هزار", "میلیون", "میلیارد"];

  String convertTo3Digits(int num) {
    String s = "";
    int d12 = num % 100;
    int d3 = (num / 100).floor();
    if (d3 != 0) s = sadgan[d3] + " و ";
    if ((d12 >= 10) && (d12 <= 19)) {
      s = s + dahyek[d12 - 10];
    } else {
      int d2 = (d12 / 10).floor();
      if (d2 != 0) s = s + dahgan[d2] + " و ";
      int d1 = d12 % 10;
      if (d1 != 0) s = s + yekan[d1] + " و ";
      s = s.substring(0, s.length - 3);
    }
    return s;
  }

  if (number < 0) return "منفی " + _numberToPersianWords(number.abs());
  if (number == 0) return "";
  
  String result = "";
  for (int i = 0; number > 0; i++) {
    int temp = number % 1000;
    if (temp != 0) {
      result = convertTo3Digits(temp) + " " + basex[i] + " و " + result;
    }
    number = (number / 1000).floor();
  }
  return result.substring(0, result.length - 3);
}

class Category {
  int id;
  String name;
  int iconCodePoint;

  Category({required this.id, required this.name, required this.iconCodePoint});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'],
        iconCodePoint: json['iconCodePoint'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'iconCodePoint': iconCodePoint};
}

class CatalogItem {
  int id;
  String name;
  double price;
  String unit;
  int categoryId;

  CatalogItem({required this.id, required this.name, required this.price, required this.unit, required this.categoryId});

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        unit: json['unit'],
        categoryId: json['categoryId'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'unit': unit, 'categoryId': categoryId};
}

class InvoiceItem extends CatalogItem {
  int invoiceId;
  double quantity;

  InvoiceItem({
    required int id,
    required String name,
    required double price,
    required String unit,
    required int categoryId,
    required this.invoiceId,
    this.quantity = 1.0,
  }) : super(id: id, name: name, price: price, unit: unit, categoryId: categoryId);
  
  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        unit: json['unit'],
        categoryId: json['categoryId'],
        invoiceId: json['invoiceId'],
        quantity: json['quantity'],
      );

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map['invoiceId'] = invoiceId;
    map['quantity'] = quantity;
    return map;
  }
}

// --- Main Application ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.vazirmatnTextTheme(Theme.of(context).textTheme);
    return MaterialApp(
      title: 'فاکتور ساز ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0891b2)),
        useMaterial3: true,
        textTheme: textTheme,
        scaffoldBackgroundColor: const Color(0xFFf0f9ff),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Home Screen with Tabs ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Category> _categories = [];
  List<CatalogItem> _catalogItems = [];
  List<InvoiceItem> _invoiceItems = [];
  final GlobalKey<AnimatedListState> _invoiceListKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  // --- Data Persistence ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> categoriesJson = _categories.map((c) => jsonEncode(c.toJson())).toList();
    List<String> catalogJson = _catalogItems.map((item) => jsonEncode(item.toJson())).toList();
    List<String> invoiceJson = _invoiceItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('categories_v7', categoriesJson);
    await prefs.setStringList('catalogItems_v7', catalogJson);
    await prefs.setStringList('invoiceItems_v7', invoiceJson);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? categoriesJson = prefs.getStringList('categories_v7');
    List<String>? catalogJson = prefs.getStringList('catalogItems_v7');
    List<String>? invoiceJson = prefs.getStringList('invoiceItems_v7');

    if (categoriesJson != null) _categories = categoriesJson.map((c) => Category.fromJson(jsonDecode(c))).toList();
    if (catalogJson != null) _catalogItems = catalogJson.map((item) => CatalogItem.fromJson(jsonDecode(item))).toList();
    if (invoiceJson != null) _invoiceItems = invoiceJson.map((item) => InvoiceItem.fromJson(jsonDecode(item))).toList();
    
    setState(() {});
  }
  
  // --- Core Logic ---
  void _addCategory(String name, int iconCodePoint) {
    setState(() {
      _categories.add(Category(id: DateTime.now().millisecondsSinceEpoch, name: name, iconCodePoint: iconCodePoint));
    });
    _saveData();
  }

  void _deleteCategory(int id) {
    setState(() {
      _categories.removeWhere((c) => c.id == id);
      _catalogItems.removeWhere((item) => item.categoryId == id);
    });
    _saveData();
  }

  void _addToCatalog(String name, double price, String unit, int categoryId) {
    setState(() {
      _catalogItems.add(CatalogItem(id: DateTime.now().millisecondsSinceEpoch, name: name, price: price, unit: unit, categoryId: categoryId));
    });
    _saveData();
  }

  void _deleteFromCatalog(int id) {
    setState(() {
      _catalogItems.removeWhere((item) => item.id == id);
    });
    _saveData();
  }

  void _addToInvoice(CatalogItem catalogItem) {
    setState(() {
      final existingItemIndex = _invoiceItems.indexWhere((item) => item.id == catalogItem.id);
      if (existingItemIndex != -1) {
        _invoiceItems[existingItemIndex].quantity++;
      } else {
        _invoiceItems.insert(0, InvoiceItem(
          id: catalogItem.id,
          name: catalogItem.name,
          price: catalogItem.price,
          unit: catalogItem.unit,
          categoryId: catalogItem.categoryId,
          invoiceId: DateTime.now().millisecondsSinceEpoch,
        ));
        if (_invoiceListKey.currentState != null) {
          _invoiceListKey.currentState!.insertItem(0, duration: const Duration(milliseconds: 500));
        }
      }
    });
    _saveData();
  }

  void _removeFromInvoice(int index) {
    final removedItem = _invoiceItems.removeAt(index);
    _invoiceListKey.currentState!.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: InvoiceItemCard(item: removedItem, onUpdate: (double quantity) {}, onRemove: (){}),
      ),
      duration: const Duration(milliseconds: 300),
    );
    setState(() {});
    _saveData();
  }

  void _updateInvoiceItem(int invoiceId, double quantity) {
     final itemIndex = _invoiceItems.indexWhere((item) => item.invoiceId == invoiceId);
    if (itemIndex != -1) {
      setState(() {
        _invoiceItems[itemIndex].quantity = quantity;
      });
    }
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0e7490), Color(0xFF06b6d4), Color(0xFF67e8f9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('پرده فروشی بهاران'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelColor: Colors.white70,
            labelColor: Colors.white,
            tabs: const [
              Tab(text: 'فاکتور جاری', icon: Icon(Icons.receipt_long)),
              Tab(text: 'کاتالوگ', icon: Icon(Icons.inventory_2)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            InvoicePage(
              invoiceItems: _invoiceItems,
              listKey: _invoiceListKey,
              onUpdate: _updateInvoiceItem,
              onRemove: _removeFromInvoice,
            ),
            CategoryListPage(
              categories: _categories,
              catalogItems: _catalogItems,
              onAddCategory: _addCategory,
              onDeleteCategory: _deleteCategory,
              onAddItem: _addToCatalog,
              onDeleteItem: _deleteFromCatalog,
              onAddToInvoice: _addToInvoice,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Category List Page ---
class CategoryListPage extends StatelessWidget {
  final List<Category> categories;
  final List<CatalogItem> catalogItems;
  final Function(String, int) onAddCategory;
  final Function(int) onDeleteCategory;
  final Function(String, double, String, int) onAddItem;
  final Function(int) onDeleteItem;
  final Function(CatalogItem) onAddToInvoice;

  const CategoryListPage({super.key, required this.categories, required this.catalogItems, required this.onAddCategory, required this.onDeleteCategory, required this.onAddItem, required this.onDeleteItem, required this.onAddToInvoice});

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => _AddCategoryDialog(onAdd: onAddCategory));
  }

  void _showDeleteCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف پوشه'),
        content: Text('آیا از حذف پوشه "${category.name}" و تمام آیتم‌های داخل آن مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('لغو')),
          ElevatedButton(
            onPressed: () {
              onDeleteCategory(category.id);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: categories.isEmpty
          ? Center(child: Text('هیچ پوشه‌ای وجود ندارد. یک پوشه جدید بسازید.', style: TextStyle(color: Colors.white70, fontSize: 16)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (ctx, index) {
                final category = categories[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => CatalogItemsPage(
                        category: category,
                        allItems: catalogItems,
                        onAddItem: onAddItem,
                        onDeleteItem: onDeleteItem,
                        onAddToInvoice: onAddToInvoice,
                      ),
                    ));
                  },
                  onLongPress: () => _showDeleteCategoryDialog(context, category),
                  borderRadius: BorderRadius.circular(20),
                  child: GlassmorphicCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'), size: 56, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                      ],
                    ),
                  ),
                ).animate().slideY(delay: (index * 70).ms, duration: 400.ms, curve: Curves.easeOut);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        label: const Text('افزودن پوشه'),
        icon: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }
}

// --- Catalog Items Page (Inside a Category) ---
class CatalogItemsPage extends StatefulWidget {
  final Category category;
  final List<CatalogItem> allItems;
  final Function(String, double, String, int) onAddItem;
  final Function(int) onDeleteItem;
  final Function(CatalogItem) onAddToInvoice;

  const CatalogItemsPage({super.key, required this.category, required this.allItems, required this.onAddItem, required this.onDeleteItem, required this.onAddToInvoice});

  @override
  State<CatalogItemsPage> createState() => _CatalogItemsPageState();
}

class _CatalogItemsPageState extends State<CatalogItemsPage> {
  late List<CatalogItem> _itemsInCategory;

  @override
  void initState() {
    super.initState();
    _updateItemsList();
  }
  
  void _updateItemsList() {
    _itemsInCategory = widget.allItems.where((item) => item.categoryId == widget.category.id).toList();
  }

  void _showAddItemDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddItemSheet(onAdd: (name, price, unit) {
        widget.onAddItem(name, price, unit, widget.category.id);
        setState(() {
          _updateItemsList();
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateItemsList();
    
    return Container(
       decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0e7490), Color(0xFF06b6d4), Color(0xFF67e8f9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.category.name)),
        body: _itemsInCategory.isEmpty
            ? Center(child: Text('این پوشه خالی است. یک آیتم جدید اضافه کنید.', style: TextStyle(color: Colors.white70, fontSize: 16)))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _itemsInCategory.length,
                itemBuilder: (ctx, index) {
                  final item = _itemsInCategory[index];
                  return InkWell(
                    onTap: () {
                      widget.onAddToInvoice(item);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} به فاکتور اضافه شد'), duration: const Duration(seconds: 1), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: GlassmorphicCard(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_getIconForUnit(item.unit), size: 48, color: Colors.white70),
                                const SizedBox(height: 12),
                                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${item.price.toStringAsFixed(0)} تومان', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                              onPressed: () {
                                widget.onDeleteItem(item.id);
                                setState(() {
                                  _updateItemsList();
                                });
                              },
                              tooltip: 'حذف از کاتالوگ',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddItemDialog(context),
          label: const Text('افزودن آیتم'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// --- Invoice Page Widget ---
class InvoicePage extends StatefulWidget {
  final List<InvoiceItem> invoiceItems;
  final GlobalKey<AnimatedListState> listKey;
  final Function(int, double) onUpdate;
  final Function(int) onRemove;

  const InvoicePage({super.key, required this.invoiceItems, required this.listKey, required this.onUpdate, required this.onRemove});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');

  Future<void> _generatePdf() async {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.vazirmatnRegular();
      final boldFont = await PdfGoogleFonts.vazirmatnBold();

      final subtotal = widget.invoiceItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      final discountPercent = double.tryParse(_persianToEnglishNumbers(_discountController.text)) ?? 0;
      final taxPercent = double.tryParse(_persianToEnglishNumbers(_taxController.text)) ?? 0;
      final discountAmount = subtotal * (discountPercent / 100);
      final grandTotal = subtotal - discountAmount + ((subtotal - discountAmount) * (taxPercent / 100));

      doc.addPage(
        pw.Page(
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('فاکتور فروش', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                        pw.Text('فروشگاه پرده بهاران'),
                      ],
                    ),
                  ),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                    cellAlignment: pw.Alignment.center,
                    headers: ['شرح', 'قیمت', 'تعداد', 'جمع کل'],
                    data: widget.invoiceItems.map((item) => [
                      item.name,
                      item.price.toStringAsFixed(0),
                      item.quantity.toString(),
                      (item.price * item.quantity).toStringAsFixed(0),
                    ]).toList(),
                  ),
                  pw.Spacer(),
                  pw.Column(
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('جمع جزء:'), pw.Text(subtotal.toStringAsFixed(0))]),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('تخفیف:'), pw.Text(discountAmount.toStringAsFixed(0))]),
                      pw.Divider(),
                      pw.DefaultTextStyle(style: pw.TextStyle(font: boldFont, fontSize: 18), child: 
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('مبلغ نهایی:'), pw.Text(grandTotal.toStringAsFixed(0))])
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('به حروف: ${_numberToPersianWords(grandTotal.toInt())} تومان', style: pw.TextStyle(font: font, fontSize: 12)),
                    ]
                  )
                ],
              ),
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = widget.invoiceItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    double discount = subtotal * (double.tryParse(_persianToEnglishNumbers(_discountController.text)) ?? 0) / 100;
    double tax = (subtotal - discount) * (double.tryParse(_persianToEnglishNumbers(_taxController.text)) ?? 0) / 100;
    double total = subtotal - discount + tax;

    return Column(
      children: [
        Expanded(
          child: widget.invoiceItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart, size: 80, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('فاکتور خالی است!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white70)),
                      const Text('برای شروع، از بخش کاتالوگ آیتمی را اضافه کنید', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ).animate().fade(duration: 300.ms)
              : AnimatedList(
                  key: widget.listKey,
                  initialItemCount: widget.invoiceItems.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index, animation) {
                    final item = widget.invoiceItems[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      child: InvoiceItemCard(
                        item: item,
                        onUpdate: (quantity) => widget.onUpdate(item.invoiceId, quantity),
                        onRemove: () => widget.onRemove(index),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 5),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: _discountController, decoration: const InputDecoration(labelText: 'تخفیف ٪', prefixIcon: Icon(Icons.percent)), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _taxController, decoration: const InputDecoration(labelText: 'مالیات ٪', prefixIcon: Icon(Icons.percent)), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                ],
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('جمع کل:', style: TextStyle(fontSize: 18)), Text('${total.toStringAsFixed(0)} تومان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('به حروف: ${_numberToPersianWords(total.toInt())} تومان', style: TextStyle(color: Colors.grey[600])),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.invoiceItems.isEmpty ? null : _generatePdf,
                icon: const Icon(Icons.print),
                label: const Text('چاپ فاکتور'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final Function(double) onUpdate;
  final VoidCallback onRemove;

  const InvoiceItemCard({super.key, required this.item, required this.onUpdate, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final quantityController = TextEditingController(text: item.quantity.toString());
    quantityController.selection = TextSelection.fromPosition(TextPosition(offset: quantityController.text.length));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(_getIconForUnit(item.unit), color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${item.price.toStringAsFixed(0)} تومان', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.remove), onPressed: () => onUpdate((item.quantity - 0.01).clamp(0.01, 9999.0))),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: quantityController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      onChanged: (value) {
                        final parsedValue = double.tryParse(_persianToEnglishNumbers(value)) ?? item.quantity;
                        onUpdate(parsedValue);
                      },
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: () => onUpdate(item.quantity + 0.01)),
                ],
              ),
            ),
            IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[700]), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final Function(String name, double price, String unit) onAdd;

  const _AddItemSheet({required this.onAdd});

  @override
  State<_AddItemSheet> createState() => __AddItemSheetState();
}

class __AddItemSheetState extends State<_AddItemSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedUnit = 'متر';

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_persianToEnglishNumbers(_priceController.text)) ?? 0;
    if (name.isNotEmpty && price > 0) {
      widget.onAdd(name, price, _selectedUnit);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام و قیمت معتبر وارد کنید.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('افزودن آیتم جدید', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'نام آیتم'), textInputAction: TextInputAction.next),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'قیمت'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => _submit())),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedUnit,
                items: ['متر', 'عدد', 'خدمات', 'متر مربع', 'قواره'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedUnit = newValue!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('ذخیره آیتم'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  final Function(String name, int iconCodePoint) onAdd;
  const _AddCategoryDialog({required this.onAdd});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  IconData _selectedIcon = Icons.category;

  final List<IconData> _icons = [
    Icons.category, Icons.style, Icons.build, Icons.content_cut,
    Icons.home, Icons.curtains, Icons.blinds, Icons.roller_shades
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ایجاد پوشه جدید'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'نام پوشه')),
          const SizedBox(height: 20),
          const Text('انتخاب آیکون:'),
          Wrap(
            spacing: 8,
            children: _icons.map((icon) => ChoiceChip(
              label: Icon(icon),
              selected: _selectedIcon == icon,
              onSelected: (selected) => setState(() => _selectedIcon = icon),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('لغو')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              widget.onAdd(_nameController.text, _selectedIcon.codePoint);
              Navigator.of(context).pop();
            }
          },
          child: const Text('ایجاد'),
        ),
      ],
    );
  }
}

// A custom widget for the glassmorphic effect
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  const GlassmorphicCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}















