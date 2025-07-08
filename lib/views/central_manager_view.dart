import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_low_energy_example/view_models.dart';
import 'package:bluetooth_low_energy_example/widgets.dart';
import 'package:clover/clover.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import 'advertisement_view.dart';

class CentralManagerView extends StatelessWidget {
  const CentralManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = ViewModel.of<CentralManagerViewModel>(context);
    final state = viewModel.state;
    final discovering = viewModel.discovering;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Manager'),
        actions: [
          TextButton(
            onPressed: state == BluetoothLowEnergyState.poweredOn
                ? () async {
                    if (discovering) {
                      await viewModel.stopDiscovery();
                    } else {
                      await viewModel.startDiscovery();
                    }
                  }
                : null,
            child: Text(discovering ? 'END' : 'BEGIN'),
          ),
        ],
      ),
      body: buildBody(context),
    );
  }

  Widget buildBody(BuildContext context) {
    final viewModel = ViewModel.of<CentralManagerViewModel>(context);
    final state = viewModel.state;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (state == BluetoothLowEnergyState.unauthorized && isMobile) {
      return Center(
        child: TextButton(
          onPressed: () => viewModel.showAppSettings(),
          child: const Text('Go to settings'),
        ),
      );
    } else if (state == BluetoothLowEnergyState.poweredOn) {
      final discoveries = viewModel.discoveries.where((discovery) {
        final serviceUUIDs = discovery.advertisement.serviceUUIDs;
        return serviceUUIDs.any(
          (uuid) => uuid.toString().toLowerCase() == targetUuid.toLowerCase(),
        );
      }).toList();

      return ListView.separated(
        itemBuilder: (context, index) {
          final theme = Theme.of(context);
          final discovery = discoveries[index];
          final uuid = discovery.peripheral.uuid;
          final name = discovery.advertisement.name;
          final rssi = discovery.rssi;
          return ListTile(
            onTap: () {
              onTapDissovery(context, discovery);
            },
            onLongPress: () {
              onLongPressDiscovery(context, discovery);
            },
            title: Text(name ?? ''),
            subtitle: Text(
              '$uuid',
              style: theme.textTheme.bodySmall,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RSSIIndicator(rssi),
                Text('$rssi'),
              ],
            ),
          );
        },
        separatorBuilder: (context, i) => const Divider(height: 0.0),
        itemCount: discoveries.length,
      );
    } else {
      return Center(
        child: Text(
          '$state',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
  }

  void onTapDiscovery(BuildContext context, DiscoveredEventArgs discovery) async {
    final centralViewModel = ViewModel.of<CentralManagerViewModel>(context);
    final peripheralViewModel = ViewModel.of<PeripheralViewModel>(context);

    if (centralViewModel.discovering) {
      await centralViewModel.stopDiscovery();
      if (!context.mounted) return;
    }

    final uuid = discovery.peripheral.uuid;

    // İkisini bir objede tutup extra ile gönderiyoruz
    final extraData = {
      'central': centralViewModel,
      'peripheral': peripheralViewModel,
      'uuid': uuid,
    };

    context.push('/chat/$uuid', extra: extraData);
  }

  void onLongPressDiscovery(
      BuildContext context, DiscoveredEventArgs discovery) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return AdvertisementView(
          advertisement: discovery.advertisement,
        );
      },
    );
  }
}
