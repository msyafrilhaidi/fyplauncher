package com.syafril.fyplauncher

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn != null) {
            // For now, we just log the package name to confirm it's working.
            // Later, we will add logic here to dismiss it.
            Log.d("NotificationListener", "Notification from: ${sbn.packageName}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
