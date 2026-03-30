import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../services/api/index.dart';
import '../theme.dart';

/// 主页包装器，包含登录状态管理和注销功能
class HomePageWrapper extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePageWrapper({Key? key, required this.onLogout}) : super(key: key);

  @override
  _HomePageWrapperState createState() => _HomePageWrapperState();
}

class _HomePageWrapperState extends State<HomePageWrapper> {
  final ApiServiceManager _apiService = ApiServiceManager.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: HomeScreen(
          // 传递额外的注销回调
          onLogout: _handleLogout,
          // 传递用户信息
          userInfo: _apiService.userInfo,
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await _showLogoutConfirmationDialog();
    if (!confirmed) {
      return;
    }

    try {
      await _apiService.logout();
      // 调用父组件的注销回调
      widget.onLogout();
      _showLogoutSuccessMessage();
    } catch (e) {
      _showLogoutErrorMessage();
    }
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出当前账号吗？退出后需要重新登录。'),
        backgroundColor: AppTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(
                color: AppTheme.lightText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showLogoutSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已成功退出账号'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showLogoutErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('退出失败，请重试'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}