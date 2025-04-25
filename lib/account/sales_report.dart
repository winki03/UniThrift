import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unithrift/account/OrderDetailsPage.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedPeriod = 'Weekly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildSalesOverview(),
            const SizedBox(height: 20),
            _buildSalesChart(),
            const SizedBox(height: 20),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Weekly', label: Text('Weekly')),
        ButtonSegment(value: 'Monthly', label: Text('Monthly')),
        ButtonSegment(value: 'Yearly', label: Text('Yearly')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
        });
      },
    );
  }

  Widget _buildSalesOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getSalesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalSales = 0;
        int totalOrders = snapshot.data!.docs.length;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalSales += (data['totalAmount'] ?? 0).toDouble();
        }

        return Row(
          children: [
            _buildOverviewCard(
              'Total Sales',
              'RM ${totalSales.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            const SizedBox(width: 16),
            _buildOverviewCard(
              'Total Orders',
              totalOrders.toString(),
              Icons.shopping_bag,
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon) {
    // Format large numbers with commas
    final formattedValue = value.startsWith('RM')
        ? 'RM ${NumberFormat('#,##0.00').format(double.parse(value.substring(3)))}'
        : value;

    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formattedValue,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Distribution by Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _getSalesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final salesByType = _processSalesByType(snapshot.data!.docs);
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _createPieChartSections(salesByType),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildChartLegend(salesByType),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _processSalesByType(List<QueryDocumentSnapshot> docs) {
    Map<String, double> salesByType = {
      'Feature': 0,
      'Rental': 0,
      'Service': 0,
    };

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'Unknown';
      final amount = (data['totalAmount'] ?? 0).toDouble();

      switch (type) {
        case 'feature':
          salesByType['Feature'] = (salesByType['Feature'] ?? 0) + amount;
          break;
        case 'rental':
          salesByType['Rental'] = (salesByType['Rental'] ?? 0) + amount;
          break;
        case 'service':
          salesByType['Service'] = (salesByType['Service'] ?? 0) + amount;
          break;
      }
    }
    return salesByType;
  }

  List<PieChartSectionData> _createPieChartSections(
      Map<String, double> salesByType) {
    final colors = [
      const Color(0xFF808569), // Feature
      const Color(0xFFE5E8D9), // Rental
      const Color(0xFF4A4E3B), // Service
    ];

    final total = salesByType.values.fold(0.0, (sum, value) => sum + value);
    List<PieChartSectionData> sections = [];
    int index = 0;

    salesByType.forEach((type, amount) {
      if (amount > 0) {
        final percentage = (amount / total) * 100;
        // Set minimum radius for small percentages
        final radius = percentage < 5 ? 70.0 : 60.0;

        sections.add(
          PieChartSectionData(
            color: colors[index],
            value: amount,
            title: percentage < 3 ? '' : '${percentage.toStringAsFixed(1)}%',
            radius: radius,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            showTitle: percentage >= 3,
          ),
        );
      }
      index++;
    });

    return sections;
  }

  Widget _buildChartLegend(Map<String, double> salesByType) {
    final colors = [
      const Color(0xFF808569), // Feature
      const Color(0xFFE5E8D9), // Rental
      const Color(0xFF4A4E3B), // Service
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: salesByType.entries.map((entry) {
        final index = salesByType.keys.toList().indexOf(entry.key);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${entry.key}: RM${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentTransactions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _getSalesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final sale = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    return _buildTransactionItem(sale);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getSalesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    DateTime startDate;
    switch (_selectedPeriod) {
      case 'Weekly':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case 'Monthly':
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      case 'Yearly':
        startDate = DateTime.now().subtract(const Duration(days: 365));
        break;
      default:
        startDate = DateTime.now().subtract(const Duration(days: 7));
    }

    return _db
        .collection('users')
        .doc(userId)
        .collection('sales')
        .where('orderDate', isGreaterThan: startDate)
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  Map<DateTime, double> _processSalesData(List<QueryDocumentSnapshot> docs) {
    Map<DateTime, double> salesData = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['orderDate'] as Timestamp).toDate();
      final amount = (data['totalAmount'] ?? 0).toDouble();

      final dateKey = DateTime(date.year, date.month, date.day);
      salesData[dateKey] = (salesData[dateKey] ?? 0) + amount;
    }

    return salesData;
  }

  LineChartData _createLineChartData(Map<DateTime, double> salesData) {
    // Implementation for chart data creation
    // This would depend on the specific chart library you're using
    return LineChartData(); // Simplified return
  }

  Widget _buildTransactionItem(Map<String, dynamic> sale) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(sale['imageUrl1'] ?? ''),
      ),
      title: Text(sale['name'] ?? 'Unknown Product'),
      subtitle: Text(
        DateFormat.yMMMd().format((sale['orderDate'] as Timestamp).toDate()),
      ),
      trailing: Text(
        'RM ${(sale['totalAmount'] ?? 0).toStringAsFixed(2)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF808569),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsPage(
              orderData: sale,
              isSeller: true, // Since this is from sales report
            ),
          ),
        );
      },
    );
  }
}
