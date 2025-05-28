part of 'cobuy_page.dart';

class AddressData {
  final int id;
  final String recipientName;
  final String phoneNumber;
  final String province;
  final String city;
  final String district;
  final String village;
  final String postalCode;
  final String streetAddress;
  final bool isPrimary;

  AddressData({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.district,
    required this.village,
    required this.postalCode,
    required this.streetAddress,
    required this.isPrimary,
  });
}

class RealtimeSubscription {
  unsubscribe() {}
}

class JavascriptMode {
  static var unrestricted;
}

class WebView {
  WebView({
    required String initialUrl, 
    required javascriptMode, 
    required NavigationDecision Function(NavigationRequest request) navigationDelegate
  });
}

class NavigationRequest {
  final String url;
  
  NavigationRequest(this.url);
}

enum NavigationDecision {
  navigate,
  prevent
}