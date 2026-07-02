import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:outline_mobileproxy/outline_mobileproxy.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outline Mobileproxy',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
      home: const ProxyDemoPage(),
    );
  }
}

class ProxyDemoPage extends StatefulWidget {
  const ProxyDemoPage({super.key});

  @override
  State<ProxyDemoPage> createState() => _ProxyDemoPageState();
}

class _ProxyDemoPageState extends State<ProxyDemoPage> {
  final _outline = OutlineMobileproxy();
  final _configController = TextEditingController(text: 'split:3');

  String _platformVersion = 'Unknown';
  ProxyInfo? _proxy;
  bool _busy = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _outline.getPlatformVersion().then((v) {
      if (mounted) setState(() => _platformVersion = v ?? 'unknown');
    });
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    final timestamp = TimeOfDay.now().format(context);
    setState(() => _log = '[$timestamp] $message\n$_log');
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final proxy = await _outline.start(transportConfig: _configController.text.trim());
      setState(() => _proxy = proxy);
      _appendLog('Started proxy at ${proxy.address}');
    } on OutlineMobileproxyException catch (e) {
      _appendLog('Failed to start: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await _outline.stop();
      setState(() => _proxy = null);
      _appendLog('Stopped proxy');
    } on OutlineMobileproxyException catch (e) {
      _appendLog('Failed to stop: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    final proxy = _proxy;
    if (proxy == null) return;

    setState(() => _busy = true);
    _appendLog('Fetching https://example.com through ${proxy.address} ...');
    try {
      final httpClient = HttpClient();
      httpClient.findProxy = (uri) => 'PROXY ${proxy.address}';
      httpClient.badCertificateCallback = (cert, host, port) => false;

      final request = await httpClient
          .getUrl(Uri.parse('https://example.com'))
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(const Duration(seconds: 15));
      await response.drain<void>();
      _appendLog('Success: HTTP ${response.statusCode}');
      httpClient.close();
    } catch (e) {
      _appendLog('Request failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _proxy != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Outline Mobileproxy Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Running on $_platformVersion', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transport config', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'e.g. split:3, ss://<userinfo>@host:port, or socks5://host:port',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _configController,
                    enabled: !isRunning,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy || isRunning ? null : _start,
                          child: const Text('Start'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy || !isRunning ? null : _stop,
                          child: const Text('Stop'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: isRunning
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(isRunning ? Icons.check_circle : Icons.circle_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(isRunning ? 'Running at ${_proxy!.address}' : 'Stopped'),
                  ),
                  if (isRunning)
                    TextButton(
                      onPressed: _busy ? null : _testConnection,
                      child: const Text('Test connection'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_log.isEmpty ? 'No activity yet.' : _log),
          ),
        ],
      ),
    );
  }
}
