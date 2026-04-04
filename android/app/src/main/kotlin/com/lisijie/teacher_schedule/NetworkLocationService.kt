package com.lisijie.teacher_schedule

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import android.util.Log

/**
 * 网络定位服务 - 仅使用 WiFi + 移动流量基站定位（完全禁用 GPS）
 */
object NetworkLocationService {
    private const val TAG = "NetworkLocationService"
    private const val LOCATION_TIMEOUT = 15000L // 15秒超时

    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    /**
     * 获取网络定位（WiFi + 移动流量）
     * @param context Context
     * @param callback 回调 (latitude, longitude) 或 null（失败时）
     */
    fun getNetworkLocation(context: Context, callback: (Double?, Double?) -> Unit) {
        try {
            locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

            // 检查权限
            if (ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "没有定位权限")
                callback(null, null)
                return
            }

            // 先检查网络定位是否可用
            if (!locationManager!!.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                Log.e(TAG, "网络定位未启用")
                callback(null, null)
                return
            }

            // 1. 先尝试获取缓存位置（最快）
            val lastKnown = locationManager!!.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (lastKnown != null) {
                Log.d(TAG, "使用缓存网络位置: ${lastKnown.latitude}, ${lastKnown.longitude}")
                callback(lastKnown.latitude, lastKnown.longitude)
                return
            }

            // 2. 请求新的网络定位
            var hasCallbacked = false

            locationListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (hasCallbacked) return
                    hasCallbacked = true

                    Log.d(TAG, "网络定位成功: ${location.latitude}, ${location.longitude}")
                    callback(location.latitude, location.longitude)

                    // 停止监听
                    stopLocationUpdates()
                }

                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            // 请求网络定位更新
            locationManager!!.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                1000L,  // 最小间隔 1 秒
                1f,     // 最小距离 1 米
                locationListener!!,
                Looper.getMainLooper()
            )

            // 设置超时
            android.os.Handler(Looper.getMainLooper()).postDelayed({
                if (!hasCallbacked) {
                    hasCallbacked = true
                    Log.e(TAG, "网络定位超时")
                    callback(null, null)
                    stopLocationUpdates()
                }
            }, LOCATION_TIMEOUT)

        } catch (e: Exception) {
            Log.e(TAG, "网络定位异常: ${e.message}")
            callback(null, null)
        }
    }

    /**
     * 停止定位监听
     */
    private fun stopLocationUpdates() {
        try {
            locationListener?.let {
                locationManager?.removeUpdates(it)
            }
            locationListener = null
        } catch (e: Exception) {
            Log.e(TAG, "停止定位监听失败: ${e.message}")
        }
    }
}
