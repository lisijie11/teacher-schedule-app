# API 集成计划

## 目标

通用教师课表应用的 API 对接规划。

## 接口列表

| 接口 | 方法 | 说明 |
|------|------|------|
| /api/auth/login | POST | 用户登录 |
| /api/schedule/weekly | GET | 获取周课表 |
| /api/user/info | GET | 获取用户信息 |
| /api/holidays | GET | 获取节假日信息 |

## 数据格式

统一使用 JSON 格式，响应结构：
```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```
