package cpp;

@:native("HWND__") extern class HWNDStruct {}
typedef HWND = cpp.Pointer<HWNDStruct>;

@:headerCode('
  #include <windows.h>
  #include <winuser.h>
  #include <dwmapi.h>
  #pragma comment(lib, "user32.lib")
  #pragma comment(lib, "dwmapi.lib")
')
class Windows
{
  @:functionCode('
    return MessageBox(hWND, (LPCSTR)lpText, (LPCSTR)lpCaption, uType);
  ')
  static function msgBox(?hWND:HWND, ?lpText:ConstCharStar, ?lpCaption:ConstCharStar, uType:Int):Int return -1;
  public static function messageBox(?window:HWND = null, ?bodyText:String,
    ?title:String, type:MessageBoxType):MessageBoxValue
  {
    if (window == null) window = getHWND();
    return msgBox(window, bodyText, title, type);
  }
  @:functionCode('
    return FindWindowA(lpClassName, lpTitleName);
  ')
  static function findWindowA(lpClassName:ConstCharStar = null, lpTitleName:ConstCharStar = null):HWND return null;
  /**
  * Finds `HWND` Handle By Title.
  */
  public static function findWindow(title:String)
    return findWindowA(null, title);
  /**
  * Returns `HWND` Handle of this window.
  */
  public static function getHWND() return findWindow(openfl.Lib.application.window.title);

  @:functionCode('
    SetWindowLongPtrA(hWND, GWL_EXSTYLE, GetWindowLongPtrA(hWND, GWL_EXSTYLE) | WS_EX_LAYERED);
    return SetLayeredWindowAttributes(hWND, RGB(r,g,b), 0, LWA_COLORKEY);
  ')
  static function setlaywindatt(hWND:HWND, r:Int,g:Int,b:Int):Bool return false;
  public static function setWindowAttributes(hWND:HWND = null, r:Int,g:Int,b:Int):Bool
  {
    if (hWND == null) hWND = getHWND();
    return setlaywindatt(hWND, r, g, b);
  }

  @:functionCode('
    int value = mode;
    ::DwmSetWindowAttribute(hWND, 20, &value, sizeof(value));
    UpdateWindow(hWND);
  ')
  static function _setdarkmode(hWND:HWND, mode:Int) {}
  public static function setDarkMode(hWND:HWND = null, mode:Bool = false)
  {
    if (hWND == null) hWND = getHWND();
    return _setdarkmode(hWND, mode ? 1 : 0);
  }
}

/**
 * Check https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messagebox
 */
enum abstract MessageBoxType(Int) from Int to Int
{
  var MB_ABORTRETRYIGNORE = 2;
  var MB_CANCELTRYCONTINUE = 6;
  var MB_HELP = 0x00004000;
  var MB_OK = 0;
  var MB_OKCANCEL = 1;
  var MB_RETRYCANCEL = 5;
  var MB_YESNO = 4;
  var MB_YESNOCANCEL = 3;

  var MB_ICONEXCLAMATION = 0x00000030;
  var MB_ICONWARNING = 0x00000030;
  var MB_ICONINFORMATION = 0x00000040;
  var MB_ICONASTERISK = 0x00000040;
  var MB_ICONQUESTION = 0x00000020;
  var MB_ICONSTOP = 0x00000010;
  var MB_ICONERROR = 0x00000010;
  var MB_ICONHAND = 0x00000010;

  var MB_DEFBUTTON1 = 0;
  var MB_DEFBUTTON2 = 0x00000100;
  var MB_DEFBUTTON3 = 0x00000200;
  var MB_DEFBUTTON4 = 0x00000300;

  var MB_APPLMODAL = 0;
  var MB_SYSTEMMODAL = 0x00001000;
  var MB_TASKMODAL = 0x00002000;
  
  var MB_DEFAULT_DESKTOP_ONLY = 0x00020000;
  var MB_RIGHT = 0x00080000;
  var MB_RTLREADING = 0x00100000;
  var MB_SETFOREGROUND = 0x00010000;
  var MB_TOPMOST = 0x00040000;
  var MB_SERVICE_NOTIFICATION = 0x00200000;
}

enum abstract MessageBoxValue(Int) from Int to Int
{
  var IDABORT = 3;
  var IDCANCEL = 2;
  var IDCONTINUE = 11;
  var IDIGNORE = 5;
  var IDNO = 7;
  var IDOK = 1;
  var IDRETRY = 4;
  var IDTRYAGAIN = 10;
  var IDYES = 6;
}