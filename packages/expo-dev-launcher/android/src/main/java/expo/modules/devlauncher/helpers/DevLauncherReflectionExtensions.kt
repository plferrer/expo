package expo.modules.devlauncher.helpers

import android.os.Build
import java.lang.reflect.Field
import java.lang.reflect.Modifier

fun <T> Class<T>.getFieldInClassHierarchy(fieldName: String): Field? {
  var currentClass: Class<*>? = this
  var result: Field? = null
  while (currentClass != null && result == null) {
    try {
      result = currentClass.getDeclaredField(fieldName)
    } catch (e: Exception) {
    }
    currentClass = currentClass.superclass
  }
  return result
}

fun <T> Class<out T>.setProtectedDeclaredField(obj: T, filedName: String, newValue: Any, predicate: (Any?) -> Boolean = { true }) {
  val field = getDeclaredField(filedName)
  field.isAccessible = true

  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    try {
      // accessFlags is supported only by API >=23
      val modifiersField = Field::class.java.getDeclaredField("accessFlags")
      modifiersField.isAccessible = true

      modifiersField.setInt(
        field,
        field.modifiers and Modifier.FINAL.inv()
      )
    } catch (e: NoSuchFieldException) {
      e.printStackTrace()
    } catch (e: IllegalAccessException) {
      e.printStackTrace()
    }
  }

  if (!predicate.invoke(field.get(obj))) {
    return
  }

  field.set(obj, newValue)
}

fun <T, U> Class<out T>.getProtectedFieldValue(obj: T, filedName: String): U {
  val field = getDeclaredField(filedName)
  field.isAccessible = true

  @Suppress("UNCHECKED_CAST")
  return field.get(obj) as U
}
