import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/widget_service.dart';
import 'today_screen.dart';
import 'schedule_screen.dart';
import 'todo_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final ValueNotifier<int>? routeNotifier;  // 外部路由通知

  const HomeScreen({super.key, this.initialIndex = 0, this.routeNotifier});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late PageController _pageController;

  List<Widget> get _screens => [
    const TodayScreen(),
    const ScheduleScreen(),
    const TodoScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetService.updateWidget();
    _pageController = PageController(initialPage: _currentIndex);

    // 监听外部路由通知
    widget.routeNotifier?.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    widget.routeNotifier?.removeListener(_onRouteChanged);
    _pageController.dispose();
    super.dispose();
  }

  /// 收到外部路由通知，切换到对应 Tab
  void _onRouteChanged() {
    final newIndex = widget.routeNotifier?.value ?? 0;
    if (newIndex != _currentIndex && newIndex >= 0 && newIndex < _screens.length) {
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() { _currentIndex = newIndex; });
      print('[HomeScreen] 路由切换到 Tab $newIndex');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: _screens,
        ),
      ),
      // 沉浸式底部导航栏（完全透明）
      bottomNavigationBar: Container(
        color: Colors.transparent,  // 完全透明
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.today_outlined, Icons.today, '今日'),
                _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, '课表'),
                _buildNavItem(2, Icons.check_circle_outline_rounded, Icons.check_circle_rounded, '待办'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final hintColor = theme.textTheme.labelSmall?.color ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? primaryColor : hintColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? primaryColor : hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
