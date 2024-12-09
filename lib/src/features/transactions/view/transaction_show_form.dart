import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/classes/db_cache.dart';
import 'package:tablets/src/common/classes/item_form_data.dart';
import 'package:tablets/src/common/functions/debug_print.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/providers/image_picker_provider.dart';
import 'package:tablets/src/common/providers/text_editing_controllers_provider.dart';
import 'package:tablets/src/common/values/constants.dart';
import 'package:tablets/src/features/settings/view/settings_keys.dart';
import 'package:tablets/src/features/transactions/controllers/form_navigator_provider.dart';
import 'package:tablets/src/features/transactions/model/transaction.dart';
import 'package:tablets/src/common/values/transactions_common_values.dart';
import 'package:tablets/src/features/transactions/view/transaction_form.dart';

class TransactionShowForm {
  static void showForm(
      BuildContext context,
      WidgetRef ref,
      ImageSliderNotifier imagePickerNotifier,
      ItemFormData formDataNotifier,
      ItemFormData settingsDataNotifier,
      TextControllerNotifier textEditingNotifier,
      StateController<Color> backgroundColorNofifier,
      {String? formType,
      Transaction? transaction,
      DbCache? transactionDbCache}) {
    if (formType == null && transaction?.transactionType == null) {
      errorPrint(
          'both formType and transaction can not be null, one of them is needed for transactionType');
      return;
    }
    String transactionType = formType ?? transaction?.transactionType as String;
    imagePickerNotifier.initialize();
    initializeFormData(
      context,
      formDataNotifier,
      settingsDataNotifier,
      transactionType,
      transaction: transaction,
      transactionDbCache: transactionDbCache,
    );
    initializeTextFieldControllers(textEditingNotifier, formDataNotifier);
    bool isEditMode = transaction != null;

    // initalize form navigator
    final formNavigator = ref.read(formNavigatorProvider);
    formNavigator.initialize(transactionType, formDataNotifier.data['dbRef']);

    showDialog(
      context: context,
      // barrierDismissible: false,
      builder: (BuildContext ctx) => TransactionForm(isEditMode, transactionType),
    ).whenComplete(() {
      imagePickerNotifier.close();
    });
  }

  static void initializeFormData(BuildContext context, ItemFormData formDataNotifier,
      ItemFormData settingsDataNotifier, String transactionType,
      {Transaction? transaction, DbCache? transactionDbCache}) {
    // note here if transaction is null, it it equivalent to calling
    // formDataNotifier.intialize();
    formDataNotifier.initialize(initialData: transaction?.toMap());
    if (transaction != null) return; // if we are in edit, we don't need further initialization
    String paymentType = settingsDataNotifier.getProperty(settingsPaymentTypeKey) ??
        S.of(context).transaction_payment_credit;
    String currenctyType = settingsDataNotifier.getProperty(settingsCurrencyKey) ??
        S.of(context).transaction_payment_Dinar;
    final transactionsData = transactionDbCache?.data;
    int? transactionNumber =
        getHighestTransactionNumber(context, transactionsData!, transactionType);
    formDataNotifier.updateProperties({
      currencyKey: translateDbTextToScreenText(context, currenctyType),
      paymentTypeKey: translateDbTextToScreenText(context, paymentType),
      discountKey: 0.0,
      transactionTypeKey: transactionType,
      dateKey: DateTime.now(),
      totalAmountKey: 0,
      totalWeightKey: 0,
      subTotalAmountKey: 0,
      transactionTotalProfitKey: 0,
      itemSalesmanTotalCommissionKey: 0,
      // if transaction is damaged item, then we set name here, because we can't easily do that
      // inside the form
      nameKey:
          transactionType == TransactionType.damagedItems.name ? S.of(context).damagedItems : null,
      salesmanKey: null,
      numberKey: transactionNumber,
      totalAsTextKey: null,
      notesKey: "",
      isPrintedKey: false,
    });
    formDataNotifier.updateSubProperties(itemsKey, emptyInvoiceItem);
  }

  // for below text field we need to add  controllers because the are updated by other fields
  // for example total price it updated by the item prices
  static void initializeTextFieldControllers(
      TextControllerNotifier textEditingNotifier, ItemFormData formDataNotifier) {
    // before creating new controllers, I dispose previous ones,
    // I previously disposed them on form close, but I did cause error say there are
    // controllers called after being disposed, so I moved the dispose here
    textEditingNotifier.disposeControllers();
    List items = formDataNotifier.getProperty(itemsKey);
    for (var i = 0; i < items.length; i++) {
      final price = formDataNotifier.getSubProperty(itemsKey, i, itemSellingPriceKey);
      final weight = formDataNotifier.getSubProperty(itemsKey, i, itemWeightKey);
      final soldQuantity = formDataNotifier.getSubProperty(itemsKey, i, itemSoldQuantityKey);
      final giftQuantity = formDataNotifier.getSubProperty(itemsKey, i, itemGiftQuantityKey);
      textEditingNotifier.updateSubControllers(itemsKey, {
        itemSellingPriceKey: price,
        itemSoldQuantityKey: soldQuantity,
        itemGiftQuantityKey: giftQuantity,
        itemTotalAmountKey: soldQuantity == null || price == null ? 0 : soldQuantity * price,
        itemTotalWeightKey: soldQuantity == null || weight == null ? 0 : soldQuantity * weight,
      });
      // I create textEditingControllers for fields that:
      // (1) changed by other fields (2) displayed in UI
      // formData like itemWeight & totalItemAmounts doesn't comply to these two condistions
      final totalAmount = formDataNotifier.getProperty(totalAmountKey);
      final totalWeight = formDataNotifier.getProperty(totalWeightKey);
      textEditingNotifier
          .updateControllers({totalAmountKey: totalAmount, totalWeightKey: totalWeight});
    }
  }

  // for every different transaction, we calculate the next number which is the last reached +1
  static int? getHighestTransactionNumber(
      BuildContext context, List<Map<String, dynamic>> transactions, String type) {
    // Step 1: Filter the list for the given transaction type
    final filteredTransactions =
        transactions.where((transaction) => transaction[transactionTypeKey] == type);
    if (filteredTransactions.isEmpty) return 1;
    // Step 2: Extract the transaction numbers and convert them to integers
    final transactionNumbers =
        filteredTransactions.map((transaction) => transaction[numberKey] as int?);
    // Step 3: Find the maximum transaction number
    int maxNumber = transactionNumbers
            .reduce((a, b) => (a != null && b != null) ? (a > b ? a : b) : (a ?? b)) ??
        0;
    return maxNumber + 1;
  }
}
