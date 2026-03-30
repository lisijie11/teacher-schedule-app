import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/holiday_service.dart';
import '../services/widget_service.dart';
import 'today_screen.dart';
import 'schedule_screen.dart';
import 'todo_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final dynamic userInfo; // 可以使用具体的UserInfo类型

  const HomeScreen({super.key, this.onLogout, this.userInfo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _slideController;
  late AnimationController _fabController;
  late PageController _pageController;
  late Animation<double> _fabAnimation;
  bool _isFabVisible = true;

  List<Widget> get _screens => [
        TodayScreen(facultyName: widget.userInfo?.facultyName),
        ScheduleScreen(userInfo: widget.userInfo),
        TodoScreen(),
        SettingsScreen(onLogout: widget.onLogout),
      ];

  @override
  void initState() {
    super.initState();
    
    // 更新桌面小组件
    WidgetService.updateWidget();
    
    // 动画控制器
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutCubic,
    );
    
    _pageController = PageController();
    
    // 监听页面滚动，隐藏/显示FAB
    _pageController.addListener(() {
      final page = _pageController.page;
      if (page == null) return;
      
      // 当接近页面边缘时隐藏FAB
      final isPageChanging = page % 1 != 0;
      if (isPageChanging != _isFabVisible) {
        setState(() {
          _isFabVisible = !isPageChanging;
          if (_isFabVisible) {
            _fabController.forward();
          } else {
            _fabController.reverse();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 页面内容
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _slideController.forward(from: 0);
            },
            children: _screens,
          ),
          
          // 页面指示器（顶部）
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: index == _currentIndex ? 24.0 : 8.0,
                    height: 4.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: index == _currentIndex
                          ? AppTheme.primaryDark.withOpacity(0.8)
                          : (isDark 
                              ? Colors.white.withOpacity(0.2) 
                              : Colors.black.withOpacity(0.1)),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
      
      // 底部导航栏
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorShape: const StadiumBorder(),
              indicatorColor: AppTheme.primaryDark.withOpacity(0.15),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                return TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(MaterialState.selected) 
                    ? FontWeight.w700 
                    : FontWeight.w500,
                );
              }),
            ),
            child: NavigationBar(
              backgroundColor: isDark 
                ? AppTheme.darkNavBackground 
                : AppTheme.lightNavBackground,
              elevation: 0,
              height: 66,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                // 添加导航栏点击动画
                _slideController.forward(from: 0);
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOutCubicEmphasized,
                );
                setState(() => _currentIndex = index);
              },
              destinations: [
                NavigationDestination(
                  tooltip: '今日课程',
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.home_menu,
                    progress: _slideController,
                    color: _currentIndex == 0 
                      ? AppTheme.primaryDark 
                      : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  selectedIcon: Icon(
                    Icons.today,
                    color: AppTheme.primaryDark,
                  ),
                  label: '今 日',
                ),
                NavigationDestination(
                  tooltip: '课程表',
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.list_view,
                    progress: _slideController,
                    color: _currentIndex == 1 
                      ? AppTheme.primaryDark 
                      : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  selectedIcon: Icon(
                    Icons.calendar_month,
                    color: AppTheme.primaryDark,
                  ),
                  label: '课 表',
                ),
                NavigationDestination(
                  tooltip: '待办事项',
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.event_add,
                    progress: _slideController,
                    color: _currentIndex == 2 
                      ? AppTheme.primaryDark 
                      : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  selectedIcon: Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryDark,
                  ),
                  label: '待 办',
                ),
                NavigationDestination(
                  tooltip: '设置',
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.settings_menu,
                    progress: _slideController,
                    color: _currentIndex == 3 
                      ? AppTheme.primaryDark 
                      : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  selectedIcon: Icon(
                    Icons.settings,
                    color: AppTheme.primaryDark,
                  ),
                  label: '设 置',
                ),
              ],
            ),
          ),
        ),
      ),
      
      // 浮动操作按钮
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          tooltip: _getFabTooltip(),
          onPressed: _handleFabPress,
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          child: _getFabIcon(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
  
  /// 获取FAB的工具提示文本
  String _getFabTooltip() {
    switch (_currentIndex) {
      case 0: // 今天页面
        return '刷新课表';
      case 1: // 课表页面
        return '添加课程';
      case 2: // 待办页面
        return '新建待办';
      case 3: // 设置页面
        return '保存设置';
      default:
        return '操作';
    }
  }
  
  /// 获取FAB图标
  Icon _getFabIcon() {
    switch (_currentIndex) {
      case 0: // 今天页面
        return const Icon(Icons.refresh_rounded, size: 24);
      case 1: // 课表页面
        return const Icon(Icons.add_rounded, size: 26);
      case 2: // 待办页面
        return const Icon(Icons.add_task_rounded, size: 24);
      case 3: // 设置页面
        return const Icon(Icons.save_rounded, size: 24);
      default:
        return const Icon(Icons.edit_rounded, size: 24);
    }
  }
  
  /// 处理FAB点击
  void _handleFabPress() {
    switch (_currentIndex) {
      case 0: // 今天页面 - 刷新课表
        _refreshTodaySchedule();
        break;
      case 1: // 课表页面 - 添加课程
        _showAddCourseDialog();
        break;
      case 2: // 待办页面 - 新建待办
        _showAddTodoDialog();
        break;
      case 3: // 设置页面 - 保存设置
        _saveSettings();
        break;
    }
    
    // 添加点击反馈
    _slideController.forward(from: 0);
  }
  
  /// 刷新今日课表
  void _refreshTodaySchedule() {
    // 这里可以调用API刷新课表
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('正在刷新课表...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// 显示添加课程对话框
  void _showAddCourseDialog() {
    // 这里可以显示添加课程的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('添加课程功能开发中...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// 显示添加待办对话框
  void _showAddTodoDialog() {
    // 这里可以显示添加待办的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('添加待办功能开发中...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// 保存设置
  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('设置已保存'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
