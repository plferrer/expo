package expo.modules.devmenu.helpers

import android.os.Build
import java.lang.reflect.Field
import java.lang.reflect.Modifier

@Suppress("UNCHECKED_CAST")
fun <T, R> Class<out T>.getPrivateDeclaredFieldValue(fieldName: String, obj: T): R {
  val field = getDeclaredField(fieldName)
  field.isAccessible = true
  return field.get(obj) as R
}

fun <T> Class<out T>.setPrivateDeclaredFieldValue(fieldName: String, obj: T, newValue: Any) {
  val field = getDeclaredField(fieldName)
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

  field.set(obj, newValue)
}
