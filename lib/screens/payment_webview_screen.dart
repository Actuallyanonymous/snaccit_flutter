import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import 'payment_status_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🌐 PaymentWebView: Loading URL: ${widget.paymentUrl}');
    debugPrint('🌐 PaymentWebView: OrderId: ${widget.orderId}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; SM-M336BU) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setOnConsoleMessage((message) {
        debugPrint('🔵 JS Console [${message.level}]: ${message.message}');
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('🌐 WebView page started: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) {
            debugPrint('🌐 WebView page finished: $url');
            if (mounted) setState(() => _isLoading = false);
            // Inject error-capturing script to monitor PhonePe's API calls
            _controller.runJavaScript('''
              (function() {
                var origFetch = window.fetch;
                window.fetch = function() {
                  return origFetch.apply(this, arguments).then(function(response) {
                    if (!response.ok) {
                      console.log('FETCH_ERROR: ' + response.url + ' status=' + response.status);
                      response.clone().text().then(function(body) {
                        console.log('FETCH_ERROR_BODY: ' + body.substring(0, 500));
                      });
                    }
                    return response;
                  }).catch(function(err) {
                    console.log('FETCH_NETWORK_ERROR: ' + err.message);
                    throw err;
                  });
                };

                var origXHR = XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.send = function() {
                  this.addEventListener('load', function() {
                    if (this.status >= 400) {
                      console.log('XHR_ERROR: ' + this.responseURL + ' status=' + this.status + ' body=' + this.responseText.substring(0, 500));
                    }
                  });
                  this.addEventListener('error', function() {
                    console.log('XHR_NETWORK_ERROR: ' + this.responseURL);
                  });
                  return origXHR.apply(this, arguments);
                };

                window.addEventListener('error', function(e) {
                  console.log('JS_ERROR: ' + e.message + ' at ' + e.filename + ':' + e.lineno);
                });

                console.log('SNACCIT_DEBUG: Error interception injected on ' + window.location.href);
              })();
            ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🌐 WebView navigation: ${request.url}');
            final url = request.url;

            // Intercept snaccit.com redirect (payment completed/cancelled)
            if (url.contains('snaccit.com/payment-status')) {
              debugPrint(
                '✅ Intercepted snaccit redirect — going to status screen',
              );
              _navigateToStatusScreen();
              return NavigationDecision.prevent;
            }

            // Intercept UPI intent URLs and launch natively
            if (url.startsWith('upi://') ||
                url.startsWith('phonepe://') ||
                url.startsWith('gpay://') ||
                url.startsWith('paytm://') ||
                url.startsWith('tez://') ||
                url.startsWith('intent://')) {
              debugPrint('📱 Intercepted UPI intent: $url');
              _launchUpiIntent(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint(
              '🌐 WebView error: ${error.errorCode} - ${error.description}',
            );
            // Don't show error for sub-resource failures (images, etc.)
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            }
          },
        ),
      )
      // Load the PhonePe payment URL directly
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _launchUpiIntent(String url) async {
    try {
      // For intent:// URLs, extract the fallback URL or try launching directly
      String launchable = url;
      if (url.startsWith('intent://')) {
        // Try to extract a fallback URL from the intent
        RegExp(r'package=([^;]+)').firstMatch(url);
        final schemeMatch = RegExp(r'scheme=([^;]+)').firstMatch(url);
        if (schemeMatch != null) {
          launchable = url.replaceFirst(
            'intent://',
            '${schemeMatch.group(1)}://',
          );
          // Remove everything after the first #
          final hashIndex = launchable.indexOf('#');
          if (hashIndex > -1) launchable = launchable.substring(0, hashIndex);
        }
        debugPrint('📱 Converted intent URL to: $launchable');
      }

      final uri = Uri.parse(launchable);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      debugPrint('📱 UPI app launched: $launched');

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No UPI app found. Please install PhonePe, Google Pay, or another UPI app.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('📱 UPI launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not open UPI app. Please try another payment method.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  void _navigateToStatusScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentStatusScreen(orderId: widget.orderId),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        title: const Text('Cancel Payment?'),
        content: const Text(
          'If you go back now, your payment may not be completed. '
          'You can check your order status in your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Continue Payment',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _navigateToStatusScreen();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceWhite,
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onWillPop,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: AppTheme.backgroundLight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading payment page...',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_hasError)
              Container(
                color: AppTheme.backgroundLight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 56,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load payment page',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your internet connection and try again',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _isLoading = true;
                          });
                          _controller.loadRequest(Uri.parse(widget.paymentUrl));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
