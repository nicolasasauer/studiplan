package com.nicolas.studiplan

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the "studiplan/backup_folder" channel: the automatic backup writes
 * into a folder the user picked once. Android only allows that through the
 * Storage Access Framework, so the folder is a tree URI with a persisted
 * permission rather than a file path.
 */
class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickFolder" -> pickFolder(result)
                "hasAccess" -> result.success(hasAccess(Uri.parse(call.arg("uri"))))
                "list" -> result.success(list(Uri.parse(call.arg("uri"))))
                "write" -> {
                    write(Uri.parse(call.arg("uri")), call.arg("name"), call.arg("content"))
                    result.success(null)
                }
                "delete" -> {
                    delete(Uri.parse(call.arg("uri")), call.arg("name"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("backup_folder", e.message, null)
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        startActivityForResult(intent, PICK_FOLDER)
    }

    @Deprecated("Deprecated in Android, still what FlutterActivity offers")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FOLDER) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            // Kept across restarts: the backup runs without asking again.
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            result.success(mapOf("uri" to uri.toString(), "name" to folderName(uri)))
        } catch (e: Exception) {
            result.error("backup_folder", e.message, null)
        }
    }

    private fun hasAccess(tree: Uri): Boolean =
        contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }

    /** Display names and document URIs of the files directly in [tree]. */
    private fun children(tree: Uri): List<Pair<String, Uri>> {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val found = mutableListOf<Pair<String, Uri>>()
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null, null, null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val name = cursor.getString(1)
                if (name != null) {
                    found += name to DocumentsContract.buildDocumentUriUsingTree(tree, id)
                }
            }
        }
        return found
    }

    private fun list(tree: Uri): List<String> = children(tree).map { it.first }

    /** Writes [content] to [name] in [tree], replacing a file of that name. */
    private fun write(tree: Uri, name: String, content: String) {
        val existing = children(tree).firstOrNull { it.first == name }?.second
        val target = existing ?: DocumentsContract.createDocument(
            contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(
                tree, DocumentsContract.getTreeDocumentId(tree)
            ),
            "application/json",
            name
        ) ?: throw IllegalStateException("Datei konnte nicht angelegt werden")
        contentResolver.openOutputStream(target, "wt")?.use {
            it.write(content.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("Datei konnte nicht geschrieben werden")
    }

    private fun delete(tree: Uri, name: String) {
        val target = children(tree).firstOrNull { it.first == name }?.second ?: return
        DocumentsContract.deleteDocument(contentResolver, target)
    }

    /** "Download/Backups" for a tree like primary:Download/Backups. */
    private fun folderName(tree: Uri): String {
        val id = DocumentsContract.getTreeDocumentId(tree)
        return id.substringAfter(':', id).ifEmpty { id }
    }

    private fun <T> MethodCall.arg(key: String): T =
        argument<T>(key) ?: throw IllegalArgumentException("$key fehlt")

    companion object {
        private const val CHANNEL = "studiplan/backup_folder"
        private const val PICK_FOLDER = 4711
    }
}
