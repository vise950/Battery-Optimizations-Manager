package com.nik.battery_optimizations_manager

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku

object ShizukuHelper {

    fun isAvailable(): Boolean {
        return try {
            Shizuku.pingBinder() &&
                    Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) {
            false
        }
    }

    fun isRunning(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (e: Exception) {
            false
        }
    }

    fun requestPermission(requestCode: Int = 0) {
        Shizuku.requestPermission(requestCode)
    }

    /**
     * Esegue un comando shell tramite Shizuku.newProcess() via reflection.
     * Shizuku.newProcess() è privato nelle versioni recenti dell'API ma
     * rimane accessibile via getDeclaredMethod + setAccessible(true).
     *
     * Questo approccio evita completamente i problemi di:
     * - hidden API enforcement (NoSuchMethodError su IDeviceIdleController)
     * - transaction code variabili tra versioni Android
     */
    private fun runCommand(command: String): Boolean {
        return try {
            val clazz = Class.forName("rikka.shizuku.Shizuku")
            val method = clazz.getDeclaredMethod(
                "newProcess",
                Array<String>::class.java,
                Array<String>::class.java,
                String::class.java
            )
            method.isAccessible = true

            val process = method.invoke(
                null,
                arrayOf("sh", "-c", command),
                null,  // env
                null   // workdir
            ) as Process

            val exitCode = process.waitFor()
            process.destroy()
            exitCode == 0
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Aggiunge un'app alla whitelist batteria (disattiva ottimizzazione).
     * Usa "+" per aggiungere alla whitelist di deviceidle.
     */
    fun addToWhitelist(packageName: String): Boolean {
        return runCommand("dumpsys deviceidle whitelist +$packageName")
    }

    /**
     * Rimuove un'app dalla whitelist batteria (riattiva ottimizzazione).
     * Usa "-" per rimuovere dalla whitelist di deviceidle.
     */
    fun removeFromWhitelist(packageName: String): Boolean {
        return runCommand("dumpsys deviceidle whitelist -$packageName")
    }

    /**
     * Aggiunge tutte le app della lista alla whitelist.
     * Prima prova con un singolo comando concatenato (più veloce),
     * in caso di errore ritenta una per una.
     */
    fun addAllToWhitelist(packageNames: List<String>): Pair<Int, Int> {
        if (packageNames.isEmpty()) return Pair(0, 0)
        return try {
            val commands = packageNames.joinToString("; ") {
                "dumpsys deviceidle whitelist +$it"
            }
            val success = runCommand(commands)
            if (success) {
                Pair(packageNames.size, 0)
            } else {
                // Fallback: uno per uno per sapere quali falliscono
                var ok = 0
                var fail = 0
                for (pkg in packageNames) {
                    if (runCommand("dumpsys deviceidle whitelist +$pkg")) ok++ else fail++
                }
                Pair(ok, fail)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Pair(0, packageNames.size)
        }
    }
}