import 'package:flutter/material.dart';

/// Global navigator key used by non-widget code (e.g. auth interceptor)
/// to perform navigation without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
