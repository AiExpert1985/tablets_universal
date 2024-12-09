import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/common/classes/db_cache.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/interfaces/screen_controller.dart';
import 'package:tablets/src/common/providers/screen_data_notifier.dart';
import 'package:tablets/src/common/values/constants.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_controller.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_controller.dart' as cust;
import 'package:tablets/src/features/customers/controllers/customer_screen_data_notifier.dart';
import 'package:tablets/src/features/customers/model/customer.dart';
import 'package:tablets/src/features/customers/repository/customer_db_cache_provider.dart';
import 'package:tablets/src/features/salesmen/controllers/salesman_screen_data_notifier.dart';
import 'package:tablets/src/features/salesmen/model/salesman.dart';
import 'package:tablets/src/features/salesmen/repository/salesman_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/model/transaction.dart';
import 'package:tablets/src/features/transactions/repository/transaction_db_cache_provider.dart';

const salesmanDbRefKey = 'dbRef';
const salesmanNameKey = 'name';
const commissionKey = 'commission';
const customersKey = 'customers';
const customersDetailsKey = 'customersDetails';
const commissionDetailsKey = 'salaryDetails';
const totalDebtsKey = 'debts';
const dueDbetsKey = 'dueDebts';
const debtsDetailsKey = 'totalDebtDetails';
const openInvoicesKey = 'openInvoices';
const openInvoicesDetailsKey = 'openInvoicesDetails';
const dueInvoicesKey = 'dueInvoices';
const profitKey = 'profit';
const profitDetailsKey = 'profitDetails';
const numInvoicesKey = 'numInvoices';
const invoicesKey = 'numInvoicesDetails';
const numReceiptsKey = 'numReceipts';
const receiptsKey = 'numReceiptsDetails';
const invoicesAmountKey = 'invoicesAmount';
const receiptsAmountKey = 'receiptsAmount';
const numReturnsKey = 'numReturns';
const returnsKey = 'numReturnsDetails';
const returnsAmountKey = 'returnsAmount';

final salesmanScreenControllerProvider = Provider<SalesmanScreenController>((ref) {
  final transactionDbCache = ref.read(transactionDbCacheProvider.notifier);
  final salesmanDbCache = ref.read(salesmanDbCacheProvider.notifier);
  final customerDbCache = ref.read(customerDbCacheProvider.notifier);
  final screenDataNotifier = ref.read(salesmanScreenDataNotifier.notifier);
  final customerScreenController = ref.read(customerScreenControllerProvider);
  final customersScreenDataNotifier = ref.read(customerScreenDataNotifier.notifier);
  return SalesmanScreenController(
    screenDataNotifier,
    transactionDbCache,
    salesmanDbCache,
    customerDbCache,
    customerScreenController,
    customersScreenDataNotifier,
  );
});

class SalesmanScreenController implements ScreenDataController {
  SalesmanScreenController(
    this._screenDataNotifier,
    this._transactionDbCache,
    this._salesmanDbCache,
    this._customerDbCache,
    this._customerScreenController,
    this._customerScreenDataNotifier,
  );

  final ScreenDataNotifier _screenDataNotifier;
  final DbCache _transactionDbCache;
  final DbCache _salesmanDbCache;
  final DbCache _customerDbCache;
  final CustomerScreenController _customerScreenController;
  final ScreenDataNotifier _customerScreenDataNotifier;

  @override
  void setFeatureScreenData(BuildContext context) {
    final allSalesmenData = _salesmanDbCache.data;
    List<Map<String, dynamic>> screenData = [];
    final allSalesmenCustomers = _getSalesmenCustomers();
    final allSalesmenTransactions = _getSalesmenTransactions();
    for (var salesmanData in allSalesmenData) {
      final salesmanDbRef = salesmanData['dbRef'];
      final salesmanCustomers = allSalesmenCustomers[salesmanDbRef]!;
      final salesmanTransactions = allSalesmenTransactions[salesmanDbRef]!;
      final newRow =
          getSalesmanScreenData(context, salesmanData, salesmanCustomers, salesmanTransactions);
      screenData.add(newRow);
    }
    Map<String, dynamic> summaryTypes = {
      commissionKey: 'sum',
      profitKey: 'sum',
    };
    _screenDataNotifier.initialize(summaryTypes);
    _screenDataNotifier.set(screenData);
  }

  List<List<dynamic>> _getInvoices(
      Map<String, List<List<dynamic>>> processedTransactionsMap, String name) {
    final transactions = processedTransactionsMap[name] ?? [[]];
    return trimLastXIndicesFromInnerLists(transactions, 2);
  }

  List<List<dynamic>> _getProfitableInvoices(
      Map<String, List<List<dynamic>>> processedTransactionsMap) {
    final invoices = processedTransactionsMap['invoicesList'] ?? [[]];
    final receipts = processedTransactionsMap['returnsList'] ?? [[]];
    final profitableInvoices = [...invoices, ...receipts];
    return removeIndicesFromInnerLists(profitableInvoices, [4, 6]);
  }

  List<List<dynamic>> _getCommissions(
      Map<String, List<List<dynamic>>> processedTransactionsMap, String name) {
    final transactions = processedTransactionsMap[name] ?? [[]];
    return removeIndicesFromInnerLists(transactions, [4, 5]);
  }

  @override
  Map<String, dynamic> getItemScreenData(BuildContext context, Map<String, dynamic> salesmanData) {
    //TODO
    // getSalesmanScreenData() should be converted to this function, but I didn't have
    // time to do it, I postponed it later.
    return {};
  }

// TODO
// the name of this function should getItemScreenData() and comply to the interface
  Map<String, dynamic> getSalesmanScreenData(
    BuildContext context,
    Map<String, dynamic> salesmanData,
    List<Customer> salesmanCustomers,
    List<Transaction> salesmanTransactions,
  ) {
    salesmanData['salary'] = salesmanData['salary'].toDouble();
    final salesman = Salesman.fromMap(salesmanData);
    // create customer screen data for all customers to fetch from it invoices status
    // and customers debt
    final customersInfo = _getCustomersInfo(salesmanCustomers);
    final customersBasicData = customersInfo['customersData'] as List<List<String>>;
    final customersDbRef = customersInfo['customersDbRef'] as List<String>;
    _customerScreenController.setFeatureScreenData(context);
    final customersDebtInfo = _getCustomersDebtInfo(customersDbRef);
    final totalDebts = customersDebtInfo[totalDebtsKey];
    final dueDebts = customersDebtInfo[dueDbetsKey];
    final debtsDetails = customersDebtInfo[debtsDetailsKey] as List<List<dynamic>>;
    final openInvoices = customersDebtInfo[openInvoicesKey];
    final dueInvoices = customersDebtInfo[dueInvoicesKey];
    final openInvoicesDetails = customersDebtInfo[openInvoicesDetailsKey] as List<List<dynamic>>;
    final numCustomers = salesmanCustomers.length;
    final processedTransactionsMap = _getProcessedTransactions(context, salesmanTransactions);
    final invoices = _getInvoices(processedTransactionsMap, 'invoicesList');
    final invoicesNumber = invoices.length;
    final invoicesAmount = sumAtIndex(invoices, 4);
    final receipts = _getInvoices(processedTransactionsMap, 'reciptsList');
    final receiptsNumber = receipts.length;
    final receiptsAmount = sumAtIndex(receipts, 4);
    final returns = _getInvoices(processedTransactionsMap, 'returnsList');
    final numReturns = returns.length;
    final returnsAmount = sumAtIndex(returns, 4);
    final profits = _getProfitableInvoices(processedTransactionsMap);
    final profitAmount = sumAtIndex(profits, 4);
    final commissions = _getCommissions(processedTransactionsMap, 'invoicesList');
    final commissionAmount = sumAtIndex(commissions, 4);
    Map<String, dynamic> newDataRow = {
      salesmanDbRefKey: salesman.dbRef,
      salesmanNameKey: salesman.name,
      commissionKey: commissionAmount,
      commissionDetailsKey: commissions,
      customersKey: numCustomers,
      customersDetailsKey: customersBasicData,
      totalDebtsKey: totalDebts,
      debtsDetailsKey: debtsDetails,
      openInvoicesKey: openInvoices,
      openInvoicesDetailsKey: openInvoicesDetails,
      profitKey: profitAmount,
      profitDetailsKey: profits,
      numInvoicesKey: invoicesNumber,
      invoicesKey: invoices,
      numReceiptsKey: receiptsNumber,
      receiptsKey: receipts,
      invoicesAmountKey: invoicesAmount,
      receiptsAmountKey: receiptsAmount,
      numReturnsKey: numReturns,
      returnsKey: returns,
      returnsAmountKey: returnsAmount,
      dueDbetsKey: dueDebts,
      dueInvoicesKey: dueInvoices,
    };
    return newDataRow;
  }

  /// create a map, its keys are salesman dbRef, and value is a list of all customers belong the the
  /// salesman, this will be used later for fetching salesman's custoemrs. this idea is used to avoid
  /// going throught the list of customers for every salesman to get his customers (performance
  /// imporvement)
  Map<String, List<Customer>> _getSalesmenCustomers() {
    // first initialize empty map with empty list for each salesman dbRef
    Map<String, List<Customer>> salesmenMap = {};
    for (var salesman in _salesmanDbCache.data) {
      final salesmanDbRef = salesman['dbRef'];
      salesmenMap[salesmanDbRef] = [];
    }
    // add customers to their salesman
    final allCustomers = _customerDbCache.data;
    for (var customer in allCustomers) {
      if (salesmenMap.containsKey(customer['salesmanDbRef'])) {
        salesmenMap[customer['salesmanDbRef']]?.add(Customer.fromMap(customer));
      }
    }
    return salesmenMap;
  }

  /// create a map, its keys are salesman dbRef, and value is a list of all transactions belong the
  /// the salesman, this will be used later for fetching salesman's custoemrs. this idea is used to
  /// avoid going throught the list of customers for every salesman to get his customers
  /// (performance imporvement)
  Map<String, List<Transaction>> _getSalesmenTransactions() {
    // first initialize empty map with empty list for each salesman dbRef
    Map<String, List<Transaction>> salesmenMap = {};
    for (var salesman in _salesmanDbCache.data) {
      final salesmanDbRef = salesman['dbRef'];
      salesmenMap[salesmanDbRef] = [];
    }
    // add customers to their salesman
    final allTransactions = _transactionDbCache.data;
    for (var transaction in allTransactions) {
      if (salesmenMap.containsKey(transaction['salesmanDbRef'])) {
        salesmenMap[transaction['salesmanDbRef']]?.add(Transaction.fromMap(transaction));
      }
    }
    return salesmenMap;
  }

  Map<String, List<List<dynamic>>> _getProcessedTransactions(
      BuildContext context, List<Transaction> salesmanTransactions) {
    List<List<dynamic>> invoicesList = [];
    List<List<dynamic>> receiptsList = [];
    List<List<dynamic>> returnsList = [];
    for (var transaction in salesmanTransactions) {
      final transactionType = translateScreenTextToDbText(context, transaction.transactionType);
      final processedTransaction = [
        transaction,
        translateDbTextToScreenText(context, transactionType),
        transaction.date,
        transaction.name,
        transaction.totalAmount,
        transaction.transactionTotalProfit,
        transaction.salesmanTransactionComssion,
      ];
      if (transactionType == TransactionType.customerInvoice.name) {
        invoicesList.add(processedTransaction);
      } else if (transactionType == TransactionType.customerReceipt.name) {
        receiptsList.add(processedTransaction);
      } else if (transactionType == TransactionType.customerReturn.name) {
        final profit = -1 * (processedTransaction[5] as double);
        processedTransaction[5] = profit;
        returnsList.add(processedTransaction);
      }
    }
    return {
      'invoicesList': invoicesList,
      'reciptsList': receiptsList,
      'returnsList': returnsList,
    };
  }

  Map<String, dynamic> _getCustomersInfo(List<Customer> salesmanCustomers) {
    List<List<String>> customerData = [];
    List<String> customerDbRef = [];
    for (var customer in salesmanCustomers) {
      customerData.add([customer.name, customer.region]);
      customerDbRef.add(customer.dbRef);
    }
    return {
      'customersDbRef': customerDbRef,
      'customersData': customerData,
    };
  }

  Map<String, dynamic> _getCustomersDebtInfo(List<String> dbRefList) {
    double totalDebt = 0;
    double dueDebt = 0;
    double openInvoices = 0;
    double dueInvoices = 0;
    List<List<dynamic>> debtsDetails = [];
    List<List<dynamic>> invoicesDetails = [];
    for (var dbRef in dbRefList) {
      final screenData = _customerScreenDataNotifier.getItem(dbRef);
      if (screenData.isEmpty) continue;
      final customerName = screenData[cust.customerNameKey] ?? '';
      final customerTotalDebt = screenData[cust.totalDebtKey] ?? 0;
      final customerDueDbet = screenData[cust.dueDebtKey] ?? 0;
      final customerOpenInvoices = screenData[cust.openInvoicesKey] ?? 0;
      final customerDueInvoices = screenData[cust.dueInvoicesKey] ?? 0;
      totalDebt += customerTotalDebt;
      dueDebt += customerDueDbet;
      openInvoices += customerOpenInvoices;
      dueInvoices += customerDueInvoices;
      debtsDetails.add([customerName, customerTotalDebt, customerDueDbet]);
      invoicesDetails.add([customerName, customerOpenInvoices, customerDueInvoices]);
    }
    Map<String, dynamic> debtInfo = {
      totalDebtsKey: totalDebt,
      dueDbetsKey: dueDebt,
      openInvoicesKey: openInvoices,
      dueInvoicesKey: dueInvoices,
      debtsDetailsKey: sortListOfListsByNumber(debtsDetails, 1),
      openInvoicesDetailsKey: sortListOfListsByNumber(invoicesDetails, 1)
    };
    return debtInfo;
  }
}
