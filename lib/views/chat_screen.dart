import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clover/clover.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy_example/view_models.dart';

class ChatScreen extends StatefulWidget {
  final String uuid;
  final CentralManagerViewModel? centralViewModel;
  final PeripheralViewModel? peripheralViewModel;

  const ChatScreen({
    super.key,
    required this.uuid,
    this.centralViewModel,
    this.peripheralViewModel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  CharacteristicViewModel? _chatCharacteristic;
  PeripheralViewModel? _peripheralViewModel;

  StreamSubscription<Uint8List>? _notifySubscription;

  @override
  void initState() {
    super.initState();
    // Async setup çağrısı
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setup();
    });
  }

  Future<void> _setup() async {
    if (widget.peripheralViewModel?.uuid != widget.uuid) {
      throw Exception('UUID eşleşmedi: ${widget.uuid}');
    }

    _peripheralViewModel = widget.peripheralViewModel;

    if (_peripheralViewModel!.connected) {
      await _peripheralViewModel?.connect();
      await _peripheralViewModel?.discoverGATT();
    }

    // "201" ile biten characteristic'ı bul
    CharacteristicViewModel? chatChar;
    for (var service in _peripheralViewModel!.serviceViewModels) {
      for (var char in service.characteristicViewModels) {
        if (char.uuid.toString().endsWith("201")) {
          chatChar = char;
          break;
        }
      }
      if (chatChar != null) break;
    }

    if (chatChar == null) {
      throw Exception('Chat karakteristiği bulunamadı');
    }

    await chatChar.setNotifyState(true);
    _chatCharacteristic = chatChar;

    // Bildirimleri kendi characteristicViewModel'dan dinle
    _notifySubscription?.cancel();
    _notifySubscription = chatChar.valueStream.listen((data) {
      if (data.isNotEmpty) {
        final text = utf8.decode(data);
        setState(() {
          _messages.add("Karşıdan: $text");
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (_chatCharacteristic != null && text.isNotEmpty) {
      final data = utf8.encode(text);
      await _chatCharacteristic!.write(Uint8List.fromList(data));
      setState(() {
        _messages.add("Sen: $text");
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = _peripheralViewModel?.name ?? widget.uuid;

    return Scaffold(
      appBar: AppBar(title: Text("Sohbet: $deviceName")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, index) =>
                  ListTile(title: Text(_messages[index])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                IconButton(
                    onPressed: _sendMessage, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
