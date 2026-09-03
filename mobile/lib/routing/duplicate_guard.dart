import 'package:auto_route/auto_route.dart';
import 'package:immich_mobile/utils/debug_print.dart';

/// Guards against duplicate navigation to this route
class DuplicateGuard extends AutoRouteGuard {
  const DuplicateGuard();
  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    // Duplicate navigation
    if (_isSameRoute(resolver.route, router.current.route)) {
      dPrint(() => 'DuplicateGuard: Preventing duplicate route navigation for ${resolver.route.name}');
      resolver.next(false);
    } else {
      resolver.next(true);
    }
  }

  bool _isSameRoute(RouteMatch nextRoute, RouteMatch currentRoute) {
    if (nextRoute.name != currentRoute.name || nextRoute.stringMatch != currentRoute.stringMatch) {
      return false;
    }
    if (nextRoute.args != currentRoute.args) {
      return false;
    }

    final nextChildren = nextRoute.children ?? const <RouteMatch>[];
    final currentChildren = currentRoute.children ?? const <RouteMatch>[];
    if (nextChildren.length != currentChildren.length) {
      return false;
    }

    for (var i = 0; i < nextChildren.length; i++) {
      if (!_isSameRoute(nextChildren[i], currentChildren[i])) {
        return false;
      }
    }

    return true;
  }
}
