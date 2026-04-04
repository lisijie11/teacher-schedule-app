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
 * 网络定位服务 - 多Provider定位（优先网络，回退GPS）
 */
object NetworkLocationService {
    private const val TAG = "NetworkLocationService"
    private const val LOCATION_TIMEOUT = 20000L // 20秒超时

    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    /**
     * 获取位置（优先网络定位，失败则尝试GPS）
     * @param context Context
     * @param callback 回调 (latitude, longitude) 或 null（失败时）
     */
    fun getNetworkLocation(context: Context, callback: (Double?, Double?) -> Unit) {
        try {
            locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

            // 检查权限
            val hasFine = ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            val hasCoarse = ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasFine && !hasCoarse) {
                Log.e(TAG, "没有定位权限")
                callback(null, null)
                return
            }

            // 检查是否有可用的定位Provider
            val providers = locationManager!!.allProviders
            Log.d(TAG, "可用的定位Provider: $providers")

            // 1. 先尝试所有Provider的缓存位置（最快）
            val cachedLocation = tryGetCachedLocation(hasFine, hasCoarse)
            if (cachedLocation != null) {
                Log.d(TAG, "使用缓存位置: ${cachedLocation.latitude}, ${cachedLocation.longitude} (${cachedLocation.provider})")
                callback(cachedLocation.latitude, cachedLocation.longitude)
                return
            }

            // 2. 尝试实时定位（优先网络，回退GPS）
            var hasCallbacked = false

            locationListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (hasCallbacked) return
                    hasCallbacked = true

                    Log.d(TAG, "定位成功: ${location.latitude}, ${location.longitude} (${location.provider})")
                    callback(location.latitude, location.longitude)
                    stopLocationUpdates()
                }

                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
                    Log.d(TAG, "Provider状态变化: $provider, status=$status")
                }
                override fun onProviderEnabled(provider: String) {
                    Log.d(TAG, "Provider启用: $provider")
                }
                override fun onProviderDisabled(provider: String) {
                    Log.d(TAG, "Provider禁用: $provider")
                }
            }

            // 优先尝试网络定位
            var requestedProvider: String? = null
            if (hasCoarse && locationManager!!.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                requestedProvider = LocationManager.NETWORK_PROVIDER
                Log.d(TAG, "尝试网络定位...")
            } else if (hasFine && locationManager!!.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                requestedProvider = LocationManager.GPS_PROVIDER
                Log.d(TAG, "网络定位不可用，尝试GPS定位...")
            } else if (hasCoarse && locationManager!!.isProviderEnabled(LocationManager.PASSIVE_PROVIDER)) {
                requestedProvider = LocationManager.PASSIVE_PROVIDER
                Log.d(TAG, "使用被动定位...")
            }

            if (requestedProvider == null) {
                Log.e(TAG, "没有可用的定位Provider")
                callback(null, null)
                return
            }

            locationManager!!.requestLocationUpdates(
                requestedProvider,
                0L,  // 最小间隔 0 秒（立即）
                0f,  // 最小距离 0 米
                locationListener!!,
                Looper.getMainLooper()
            )

            // 设置超时
            android.os.Handler(Looper.getMainLooper()).postDelayed({
                if (!hasCallbacked) {
                    hasCallbacked = true
                    Log.e(TAG, "定位超时（20秒）")
                    callback(null, null)
                    stopLocationUpdates()
                }
            }, LOCATION_TIMEOUT)

        } catch (e: Exception) {
            Log.e(TAG, "定位异常: ${e.message}")
            e.printStackTrace()
            callback(null, null)
        }
    }

    /**
     * 尝试从所有Provider获取缓存位置
     */
    private fun tryGetCachedLocation(hasFine: Boolean, hasCoarse: Boolean): Location? {
        val providers = listOfNotNull(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.GPS_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )

        for (provider in providers) {
            try {
                val location = locationManager?.getLastKnownLocation(provider)
                if (location != null) {
                    // 检查位置是否在合理范围内（最近24小时）
                    val age = System.currentTimeMillis() - location.time
                    if (age < 24 * 60 * 60 * 1000) { // 24小时内
                        return location
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "获取 $provider 缓存失败: ${e.message}")
            }
        }
        return null
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
