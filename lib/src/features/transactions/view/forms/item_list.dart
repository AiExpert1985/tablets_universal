import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/classes/db_cache.dart';
import 'package:tablets/src/common/classes/db_repository.dart';
import 'package:tablets/src/common/classes/item_form_data.dart';
import 'package:tablets/src/common/functions/debug_print.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/providers/text_editing_controllers_provider.dart';
import 'package:tablets/src/common/values/constants.dart' as constants;
import 'package:tablets/src/common/values/constants.dart';
import 'package:tablets/src/common/values/features_keys.dart';
import 'package:tablets/src/common/values/form_dimenssions.dart';
import 'package:tablets/src/common/widgets/form_fields/drop_down_with_search.dart';
import 'package:tablets/src/common/widgets/form_fields/edit_box.dart';
import 'package:tablets/src/common/values/transactions_common_values.dart';
import 'package:tablets/src/features/products/controllers/product_screen_controller.dart';
import 'package:tablets/src/features/products/repository/product_db_cache_provider.dart';
import 'package:tablets/src/features/products/repository/product_repository_provider.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_form_data_notifier.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_utils_controller.dart';

const double sequenceColumnWidth = customerInvoiceFormWidth * 0.055;
const double nameColumnWidth = customerInvoiceFormWidth * 0.345;
const double priceColumnWidth = customerInvoiceFormWidth * 0.16;
const double soldQuantityColumnWidth = customerInvoiceFormWidth * 0.1;
const double giftQuantityColumnWidth = customerInvoiceFormWidth * 0.1;
const double soldTotalAmountColumnWidth = customerInvoiceFormWidth * 0.17;

class ItemsList extends ConsumerWidget {
  const ItemsList(this.hideGifts, this.hidePrice, this.transactionType, {super.key});

  final bool hideGifts;
  final bool hidePrice;
  final String transactionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formDataNotifier = ref.read(transactionFormDataProvider.notifier);
    final productRepository = ref.read(productRepositoryProvider);
    final textEditingNotifier = ref.read(textFieldsControllerProvider.notifier);
    final productDbCache = ref.read(productDbCacheProvider.notifier);
    final productScreenController = ref.read(productScreenControllerProvider);
    return Container(
      height: 350,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black38, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildColumnTitles(context, formDataNotifier, textEditingNotifier, hideGifts, hidePrice),
            ..._buildDataRows(formDataNotifier, textEditingNotifier, productRepository, hideGifts, hidePrice,
                transactionType, productDbCache, productScreenController, context),
          ],
        ),
      ),
    );
  }
}

List<Widget> _buildDataRows(
  ItemFormData formDataNotifier,
  TextControllerNotifier textEditingNotifier,
  DbRepository productRepository,
  bool hideGifts,
  bool hidePrice,
  String transactionType,
  DbCache productDbCache,
  ProductScreenController productScreenController,
  BuildContext context,
) {
  if (!formDataNotifier.data.containsKey(itemsKey) || formDataNotifier.data[itemsKey] is! List) {
    return const [];
  }
  final items = formDataNotifier.data[itemsKey] as List<Map<String, dynamic>>;
  return List.generate(items.length, (index) {
    if (!textEditingNotifier.data.containsKey(itemsKey) || textEditingNotifier.data[itemsKey]!.length <= index) {
      errorPrint('Warning: Missing TextEditingController for item index: $index');
      return const SizedBox.shrink(); // Return an empty widget if the controller is missing
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      // buildDataCell(sequenceColumnWidth, Text((index + 1).toString()), isFirst: true),
      _buildDeleteItemButton(formDataNotifier, textEditingNotifier, index, sequenceColumnWidth, transactionType,
          isFirst: true),
      _buildDropDownWithSearch(formDataNotifier, textEditingNotifier, index, nameColumnWidth, productDbCache,
          productScreenController, context, items.length),

      TransactionFormInputField(index, soldQuantityColumnWidth, itemsKey, itemSoldQuantityKey, transactionType),
      if (!hideGifts)
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.red, // Set the border color to red
              width: 0.5, // Set the border width
            ),
            borderRadius: BorderRadius.circular(8.0), // Optional: Set border radius
          ),
          child:
              TransactionFormInputField(index, giftQuantityColumnWidth, itemsKey, itemGiftQuantityKey, transactionType),
        ),

      if (!hidePrice)
        TransactionFormInputField(index, priceColumnWidth, itemsKey, itemSellingPriceKey, transactionType),
      if (!hidePrice)
        TransactionFormInputField(index, soldTotalAmountColumnWidth, itemsKey, itemTotalAmountKey, transactionType,
            // textEditingNotifier: textEditingNotifier,
            isLast: false,
            isReadOnly: true),
      buildDataCell(soldQuantityColumnWidth,
          Text(formDataNotifier.getSubProperty(itemsKey, index, itemStockQuantityKey)?.toString() ?? ''),
          isLast: true),
    ]);
  });
}

Widget _buildAddItemButton(ItemFormData formDataNotifier, TextControllerNotifier textEditingNotifier) {
  return IconButton(
    onPressed: () {
      formDataNotifier.updateSubProperties(itemsKey, emptyInvoiceItem);
      textEditingNotifier.updateSubControllers(itemsKey, {
        itemSellingPriceKey: 0,
        itemSoldQuantityKey: 0,
        itemGiftQuantityKey: 0,
        itemTotalAmountKey: 0,
        itemTotalWeightKey: 0
      });
    },
    icon: const Icon(Icons.add, color: Colors.green),
  );
}

void addNewRow(formDataNotifier, textEditingNotifier) {
  formDataNotifier.updateSubProperties(itemsKey, emptyInvoiceItem);
  textEditingNotifier.updateSubControllers(itemsKey, {
    itemSellingPriceKey: 0,
    itemSoldQuantityKey: 0,
    itemGiftQuantityKey: 0,
    itemTotalAmountKey: 0,
    itemTotalWeightKey: 0
  });
}

// TODO when last item removed, there still data, i need to solve that
// TODO I was working on using remove textEditingController.subControllers(...) but
// TODO stopped due to lack of time
Widget _buildDeleteItemButton(ItemFormData formDataNotifier, TextControllerNotifier textEditingNotifier, int index,
    double width, String transactionType,
    {bool isFirst = false}) {
  return buildDataCell(
      width,
      IconButton(
        onPressed: () {
          final items = formDataNotifier.getProperty(itemsKey) as List<Map<String, dynamic>>;
          final deletedItem = {...items[index]};
          // if there is only one item, it is not deleted, but formData & textEditingData is reseted
          if (items.length <= 1) {
            formDataNotifier.updateSubProperties(itemsKey, emptyInvoiceItem, index: 0);
          } else {
            formDataNotifier.removeSubProperties(itemsKey, index);
            textEditingNotifier.removeSubController(itemsKey, index, itemSellingPriceKey);
          }

          // update all transaction totals due to item removal
          final subTotalAmount = _getTotal(formDataNotifier, itemsKey, subTotalAmountKey);
          final discount = formDataNotifier.getProperty(discountKey);
          // for gifts we don't charget customer
          final totalAmount = transactionType == TransactionType.gifts.name ? 0 : subTotalAmount - discount;
          final totalWeight = _getTotal(formDataNotifier, itemsKey, itemTotalWeightKey);
          double totalSalesmanCommission = formDataNotifier.getProperty(salesmanTransactionComssionKey);
          final itemSalesmanCommission = deletedItem[itemSalesmanTotalCommissionKey];
          totalSalesmanCommission -= itemSalesmanCommission;
          double itemsTotalProfit = formDataNotifier.getProperty(itemsTotalProfitKey);
          final itemProfit = deletedItem[itemTotalProfitKey];
          itemsTotalProfit -= itemProfit;
          final transactionTotalProfit = itemsTotalProfit - discount - totalSalesmanCommission;
          formDataNotifier.updateProperties({
            totalAmountKey: totalAmount,
            totalWeightKey: totalWeight,
            salesmanTransactionComssionKey: totalSalesmanCommission,
            itemsTotalProfitKey: itemsTotalProfit,
            transactionTotalProfitKey: transactionTotalProfit,
          });
          textEditingNotifier.updateControllers({totalAmountKey: totalAmount, totalWeightKey: totalWeight});
        },
        icon: const Icon(Icons.remove, color: Colors.red),
      ),
      isFirst: true);
}

Widget _buildColumnTitles(BuildContext context, ItemFormData formDataNotifier,
    TextControllerNotifier textEditingNotifier, bool hideGifts, bool hidePrice) {
  final titles = [
    _buildAddItemButton(formDataNotifier, textEditingNotifier),
    Text(S.of(context).item_name),
    Text(S.of(context).item_sold_quantity),
    if (!hideGifts) Text(S.of(context).item_gifts_quantity),
    if (!hidePrice) Text(S.of(context).item_price),
    if (!hidePrice) Text(S.of(context).item_total_price),
    Text(S.of(context).stock),
  ];

  final widths = [
    sequenceColumnWidth,
    nameColumnWidth,
    soldQuantityColumnWidth,
    if (!hideGifts) giftQuantityColumnWidth,
    if (!hidePrice) priceColumnWidth,
    if (!hidePrice) soldTotalAmountColumnWidth,
    soldQuantityColumnWidth,
  ];

  return Container(
    color: const Color.fromARGB(255, 227, 240, 247),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      ...List.generate(titles.length, (index) {
        return buildDataCell(
          widths[index],
          titles[index],
          isTitle: true,
          isFirst: index == 0,
          isLast: index == titles.length - 1,
        );
      })
    ]),
  );
}

dynamic _getTotal(ItemFormData formDataNotifier, String property, String subProperty) {
  dynamic total = 0;
  if (!formDataNotifier.isValidProperty(property) ||
      formDataNotifier.getProperty(property) is! List<Map<String, dynamic>>) {
    errorPrint('form property provided is invalid');
    return total;
  }
  final items = formDataNotifier.getProperty(property);
  for (var i = 0; i < items.length; i++) {
    if (!items[i].containsKey(subProperty)) {
      errorPrint('formData[$property][$i][$subProperty] is invalid');
      continue;
    }
    final value = items[i][subProperty];
    if (value is! double && value is! int) {
      errorPrint('$subProperty[$subProperty] is not a nummber');
      continue;
    }
    total += value;
  }
  return total;
}

Widget _buildDropDownWithSearch(
    ItemFormData formDataNotifier,
    TextControllerNotifier textEditingNotifier,
    int index,
    double width,
    DbCache productDbCache,
    ProductScreenController productScreenController,
    BuildContext context,
    int numRows) {
  return buildDataCell(
    width,
    DropDownWithSearchFormField(
      initialValue: formDataNotifier.getSubProperty(itemsKey, index, itemNameKey),
      hideBorders: true,
      dbCache: productDbCache,
      isRequired: false,
      onChangedFn: (item) {
        // calculate the quantity of the product
        final productData = productDbCache.getItemByDbRef(item['dbRef']);
        final prodcutScreenData = productScreenController.getItemScreenData(context, productData);
        final productQuantity = prodcutScreenData[productQuantityKey];
        // updates related fields using the item selected (of type Map<String, dynamic>)
        // and triger the on changed function in price field using its controller
        final subProperties = {
          itemNameKey: item['name'],
          itemDbRefKey: item['dbRef'],
          itemSellingPriceKey: _getItemPrice(context, formDataNotifier, item),
          itemWeightKey: item['packageWeight'],
          itemBuyingPriceKey: item['buyingPrice'],
          itemSalesmanCommissionKey: item['salesmanCommission'],
          itemStockQuantityKey: productQuantity,
        };
        formDataNotifier.updateSubProperties(itemsKey, subProperties, index: index);
        final price = formDataNotifier.getSubProperty(itemsKey, index, itemSellingPriceKey);
        textEditingNotifier.updateSubControllers(itemsKey, {itemSellingPriceKey: price}, index: index);
// add new empty row if current row is last one, (always keep one empty row)
        if (index == numRows - 1) {
          addNewRow(formDataNotifier, textEditingNotifier);
        }
      },
    ),
  );
}

class TransactionFormInputField extends ConsumerWidget {
  const TransactionFormInputField(this.index, this.width, this.property, this.subProperty, this.transactionType,
      {this.isLast = false, this.isReadOnly = false, super.key});

  final int index;
  final double width;
  final String property;
  final String subProperty;
  final String transactionType;
  final bool isLast;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formDataNotifier = ref.read(transactionFormDataProvider.notifier);
    final textEditingNotifier = ref.read(textFieldsControllerProvider.notifier);
    final transactionUtils = ref.read(transactionUtilsControllerProvider);
    return buildDataCell(
      width,
      FormInputField(
        initialValue: formDataNotifier.getSubProperty(property, index, subProperty),
        controller: textEditingNotifier.getSubController(property, index, subProperty),
        hideBorders: true,
        isRequired: false,
        isReadOnly: isReadOnly,
        dataType: constants.FieldDataType.num,
        name: subProperty,
        onChangedFn: (value) {
          // this method is executed throught two ways, first when the field is updated by the user
          // and the second is automatic when user selects and item through adjacent product selection dropdown
          formDataNotifier.updateSubProperties(property, {subProperty: value}, index: index);
          final sellingPrice = formDataNotifier.getSubProperty(property, index, itemSellingPriceKey);
          final weight = formDataNotifier.getSubProperty(property, index, itemWeightKey);
          final soldQuantity = formDataNotifier.getSubProperty(property, index, itemSoldQuantityKey);
          if (soldQuantity == null || sellingPrice == null) {
            return;
          }
          final updatedSubProperties = {
            itemTotalAmountKey: soldQuantity * sellingPrice,
            itemTotalWeightKey: soldQuantity * weight
          };
          formDataNotifier.updateSubProperties(property, updatedSubProperties, index: index);
          textEditingNotifier.updateSubControllers(property, updatedSubProperties, index: index);
          final subTotalAmount = _getTotal(formDataNotifier, property, itemTotalAmountKey);
          formDataNotifier.updateProperties({subTotalAmountKey: subTotalAmount});
          final itemsTotalWeight = _getTotal(formDataNotifier, property, itemTotalWeightKey);
          final discount = formDataNotifier.getProperty(discountKey);
          // for gifts we don't charget customer
          final totalAmount = transactionType == TransactionType.gifts.name ? 0 : subTotalAmount - discount;
          final updatedProperties = {totalAmountKey: totalAmount, totalWeightKey: itemsTotalWeight};
          formDataNotifier.updateProperties(updatedProperties);
          textEditingNotifier.updateControllers(updatedProperties);
          // calculate total profit & salesman commision on item
          final giftQuantity = formDataNotifier.getSubProperty(property, index, itemGiftQuantityKey);
          if (giftQuantity == null) return;
          final buyingPrice = formDataNotifier.getSubProperty(property, index, itemBuyingPriceKey);
          final salesmanCommission = formDataNotifier.getSubProperty(property, index, itemSalesmanCommissionKey);
          final salesmanTotalCommission = salesmanCommission * soldQuantity;
          final itemTotalProfit = ((sellingPrice - buyingPrice) * soldQuantity) - (giftQuantity * buyingPrice);

          formDataNotifier.updateSubProperties(
              property, {itemSalesmanTotalCommissionKey: salesmanTotalCommission, itemTotalProfitKey: itemTotalProfit},
              index: index);
          final itemsTotalProfit = _getTotal(formDataNotifier, property, itemTotalProfitKey);
          final salesmanTransactionComssion = _getTotal(formDataNotifier, property, itemSalesmanTotalCommissionKey);
          double transactionTotalProfit = transactionUtils.getTransactionProfit(
              formDataNotifier, transactionType, itemsTotalProfit, discount, salesmanTransactionComssion);
          formDataNotifier.updateProperties(
            {
              itemsTotalProfitKey: itemsTotalProfit,
              transactionTotalProfitKey: transactionTotalProfit,
              salesmanTransactionComssionKey: salesmanTransactionComssion
            },
          );
        },
      ),
      isLast: isLast,
    );
  }
}

Widget buildDataCell(double width, Widget cell, {height = 45, isTitle = false, isFirst = false, isLast = false}) {
  return Container(
      decoration: BoxDecoration(
        border: Border(
            left: !isLast ? const BorderSide(color: Colors.black12, width: 1.0) : BorderSide.none,
            right: !isFirst ? const BorderSide(color: Colors.black12, width: 1.0) : BorderSide.none,
            bottom: const BorderSide(color: Colors.black12, width: 1.0)),
      ),
      width: width,
      height: height is double ? height : height.toDouble(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          cell,
        ],
      ));
}

// item price is not the same for all customers, it depends on selling type to the customer,
// if customer is not selected yet then default is salewhole type
double _getItemPrice(BuildContext context, ItemFormData formDataNotifier, Map<String, dynamic> item) {
  final transactionType = formDataNotifier.getProperty(transactionTypeKey);
  if (transactionType == TransactionType.expenditures.name ||
      transactionType == TransactionType.customerReceipt.name ||
      transactionType == TransactionType.vendorReceipt.name) {
    errorPrint('Wrong form type');
    return 0;
  }
  // for vendor we use buying price
  if (transactionType == TransactionType.vendorInvoice.name || transactionType == TransactionType.vendorReturn.name) {
    return item['buyingPrice'];
  }

  String? customerSellType = formDataNotifier.getProperty(sellingPriceTypeKey);
  if (customerSellType == null) return item['sellRetailPrice'];
  customerSellType = translateScreenTextToDbText(context, customerSellType);
  final price = customerSellType == SellPriceType.retail.name ? item['sellRetailPrice'] : item['sellWholePrice'];
  return price;
}
