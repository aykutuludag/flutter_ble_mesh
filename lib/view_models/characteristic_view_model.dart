import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_low_energy_example/models.dart';
import 'package:clover/clover.dart';

import 'descriptor_view_model.dart';

class CharacteristicViewModel extends ViewModel {
  final CentralManager _manager;
  final Peripheral _peripheral;
  final GATTCharacteristic _characteristic;
  final List<DescriptorViewModel> _descriptorViewModels;
  final List<Log> _logs;

  GATTCharacteristicWriteType _writeType;
  bool _notifyState;

  late final StreamSubscription _characteristicNotifiedSubscription;

  // Yeni: Dışarıya notify değerlerini yaymak için stream controller
  final StreamController<Uint8List> _valueStreamController = StreamController.broadcast();

  // Yeni: Notify değerlerini dinlemek için public stream
  Stream<Uint8List> get valueStream => _valueStreamController.stream;

  CharacteristicViewModel({
    required CentralManager manager,
    required Peripheral peripheral,
    required GATTCharacteristic characteristic,
  })  : _manager = manager,
        _peripheral = peripheral,
        _characteristic = characteristic,
        _descriptorViewModels = characteristic.descriptors
            .map((descriptor) => DescriptorViewModel(descriptor))
            .toList(),
        _logs = [],
        _writeType = GATTCharacteristicWriteType.withResponse,
        _notifyState = false {
    if (!canWrite && canWriteWithoutResponse) {
      _writeType = GATTCharacteristicWriteType.withoutResponse;
    }
    _characteristicNotifiedSubscription =
        _manager.characteristicNotified.listen((eventArgs) {
          if (eventArgs.characteristic != _characteristic) {
            return;
          }
          final value = eventArgs.value;

          // Yeni: Gelen notify değerini dışarıya yay
          _valueStreamController.add(value);

          final log = Log(
            type: 'Notified',
            message: '[${value.length}] $value',
          );
          _logs.add(log);
          notifyListeners();
        });
  }

  UUID get uuid => _characteristic.uuid;

  // Yeni: _characteristic dışarı açıldı
  GATTCharacteristic get characteristic => _characteristic;

  bool get canRead =>
      _characteristic.properties.contains(GATTCharacteristicProperty.read);
  bool get canWrite =>
      _characteristic.properties.contains(GATTCharacteristicProperty.write);
  bool get canWriteWithoutResponse => _characteristic.properties
      .contains(GATTCharacteristicProperty.writeWithoutResponse);
  bool get canNotify =>
      _characteristic.properties.contains(GATTCharacteristicProperty.notify) ||
          _characteristic.properties.contains(GATTCharacteristicProperty.indicate);
  List<DescriptorViewModel> get descriptorViewModels => _descriptorViewModels;
  List<Log> get logs => _logs;
  GATTCharacteristicWriteType get writeType => _writeType;
  bool get notifyState => _notifyState;

  Future<void> read() async {
    final value = await _manager.readCharacteristic(
      _peripheral,
      _characteristic,
    );
    final log = Log(
      type: 'Read',
      message: '[${value.length}] $value',
    );
    _logs.add(log);
    notifyListeners();
  }

  void setWriteType(GATTCharacteristicWriteType type) {
    if (type == GATTCharacteristicWriteType.withResponse && !canWrite) {
      throw ArgumentError.value(type);
    }
    if (type == GATTCharacteristicWriteType.withoutResponse &&
        !canWriteWithoutResponse) {
      throw ArgumentError.value(type);
    }
    _writeType = type;
    notifyListeners();
  }

  Future<void> write(Uint8List value) async {
    // Fragments the value by maximumWriteLength.
    final fragmentSize = await _manager.getMaximumWriteLength(
      _peripheral,
      type: writeType,
    );
    var start = 0;
    while (start < value.length) {
      final end = start + fragmentSize;
      final fragmentedValue =
      end < value.length ? value.sublist(start, end) : value.sublist(start);
      final type = writeType;
      await _manager.writeCharacteristic(
        _peripheral,
        _characteristic,
        value: fragmentedValue,
        type: type,
      );
      final log = Log(
        type: type == GATTCharacteristicWriteType.withResponse
            ? 'Write'
            : 'Write without response',
        message: '[${value.length}] $value',
      );
      _logs.add(log);
      notifyListeners();
      start = end;
    }
  }

  Future<void> setNotifyState(bool state) async {
    await _manager.setCharacteristicNotifyState(
      _peripheral,
      _characteristic,
      state: state,
    );
    _notifyState = state;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _characteristicNotifiedSubscription.cancel();
    _valueStreamController.close();
    for (var descriptorViewModel in descriptorViewModels) {
      descriptorViewModel.dispose();
    }
    super.dispose();
  }
}