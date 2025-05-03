package cpp;

import cpp.Windows.MessageBoxValue;
import cpp.Windows.MessageBoxType;
import flixel.*;
import flixel.util.FlxColor;
class CppAPI
{
  #if cpp
  /**
    Shows An Message Box to Player.
    @param text Message Box's Text.
    @param title Message Box's Title. If Not Set, The Default would be `Error`.
    @param type Message Box's Type.
  **/
  public static function showMessageBox(?text:String, ?title:String = 'Error', type:MessageBoxType):MessageBoxValue
    return Windows.messageBox(null, text, title, type);

  /**
    Sets Transparent Color of Window.
    If it failed, returns `false`.

    WARNING: IF YOU USE THIS FUNCTION, IT WILL BE NOT ABLE TO MOVE OR SCALE WINDOW YOURSELF.
    
    And If you use `Lib.application.window.opacity` or `Application.current.window.opacity` resets this function!
  **/
  public static function setAlphaColor(color:FlxColor)
    return Windows.setWindowAttributes(color.red, color.green, color.blue);
  /**
    Sets Dark Mode of Window.
  **/
  public static function setDarkBorder(value:Bool = true)
    return Windows.setDarkMode(value);
  /**
    Enables Desktop or not.

    If Not Enabled, Desktop will use Solid Color.
  **/
  public static function enableDesktop(enable:Bool = false) Desktop.enable(enable);
  /**
    Gets Desktop's Solid Color
  **/
  public static function getDesktopColor():FlxColor return Desktop.getBackgroundColor();
  /**
    Gets Monitor ID By Index.
  **/
  public static function getMonitorByID(index:Int) return Desktop.getMonitorByID(index);
  /**
    Gets Monitor's Count.
  **/
  public static function getMonitorCount() return Desktop.getMonitorCount();
  /**
    Sets Solid Color of Desktop.
  **/
  public static function setDesktopColor(color:FlxColor)
    Desktop.setBackgroundColor(color.red, color.green, color.blue);
  /**
    Sets Wallpaper Image.

    @param device Monitor ID.
    @param image An Wallpaper Image's Full Path.
  **/
  public static function setWallpaper(device:String, image:String) Desktop.setWallpaper(device, image);
  /**
    Gets Wallpaper Image.

    @param device Monitor ID.
    @return An Wallpaper Image's full path.
  **/
  public static function getWallpaper(device:String) return Desktop.getWallpaper(device);
  /**
    Gets Monitor's Size.

    @param device Monitor ID.
  **/
  public static function getMonitorSize(device:String)
    return [Desktop.getMonitorWidth(device), Desktop.getMonitorHeight(device)];
  #end
}