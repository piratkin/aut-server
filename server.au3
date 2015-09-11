#include <Constants.au3> ; для константы $TRAY_...
#include <hosts.au3>
#NoTrayIcon
;
Opt("TrayOnEventMode", 1)
Opt("GUIOnEventMode", 1)
Opt("SendCapslockMode", 0)
Opt("TrayMenuMode", 1 + 2)
;ограничиваем запуск нескольких коппий программы
$uniq_script_name = 'PHP_NGINX_MYSQL'
If WinExists($uniq_script_name, '') Then
	MsgBox(0, "Ошибка!", "Предыдущий скрипт не был завершен!")
    Exit
EndIf
AutoItWinSetTitle($uniq_script_name)
;текущая дата в нужном формате
$CRDATE = @MDAY & "." & @MON & "." & @YEAR & ' ' & @HOUR & ":" & @MIN
;определяем расположение рабочих файлов и создаем лог
$name = StringRegExpReplace(@ScriptFullPath, '^.*\\|\.[^\.]*$', '')
$cfg_ini = @ScriptDir & "\" & $name & ".ini"
$cfg_log = @ScriptDir & "\" & $name & ".log"
$log_fle = FileOpen( $cfg_log, 1)
FileWrite($log_fle, @CRLF & $CRDATE & ': Конфигуратор запущен...' & @CRLF)
;создаем меню
$setoptions = TrayCreateItem("Настройки")
              TrayCreateItem("")
$reboot     = TrayCreateItem("Перезапуск")
              TrayCreateItem("")
$term       = TrayCreateItem("Терминал")
              TrayCreateItem("")
$ftp_menu   = TrayCreateMenu("FTP-сервер")
$ftp_start  = TrayCreateItem("Старт",   $ftp_menu)
$ftp_reset  = TrayCreateItem("Рестарт", $ftp_menu)
$ftp_stop   = TrayCreateItem("Стоп",    $ftp_menu) 
              TrayCreateItem("")
$exititem   = TrayCreateItem("Выход")
;настраиваем подменю ftp-сервера
TrayItemSetState($ftp_start, $TRAY_ENABLE)
TrayItemSetState($ftp_stop,  $TRAY_DISABLE)
TrayItemSetState($ftp_reset, $TRAY_DISABLE)
;привязываем обработчики событий
TrayItemSetOnEvent($ftp_start,  "start_ftp_server")
TrayItemSetOnEvent($ftp_reset,  "reset_ftp_server")
TrayItemSetOnEvent($ftp_stop,   "stop_ftp_server")
TrayItemSetOnEvent($setoptions, "t_Options")
TrayItemSetOnEvent($reboot,     "t_Reboot")
TrayItemSetOnEvent($term,       "t_Run")
TrayItemSetOnEvent($exititem,   "t_Quit")
OnAutoItExitRegister('_Quit')
;инициализируем переменные для работы программы
$exe_php    = "php-cgi.exe"
$exe_sql    = "mysqld.exe"
$exe_ngx    = "nginx.exe"
$exe_ftp    = "slimftpd.exe"
$f_php      = False
$f_ngx      = False
$f_sql      = False
$f_ico      = False
$sync_delay = 0
$opt_sync   = 0
$rbt_sync   = 0
$qut_sync   = 0
$cmd_sync   = 0
$root_dir   = ""
$ftp_state = 0
;читаем конфиг
$path_dir = IniRead($cfg_ini, "GENERAL", "dir", @ScriptDir)
$path_php = IniRead($cfg_ini, "GENERAL", "php", $path_dir   & "php\")
$path_git = IniRead($cfg_ini, "GENERAL", "git", $path_dir   & "git\bin\")
$path_sql = IniRead($cfg_ini, "GENERAL", "sql", $path_dir   & "mysql\bin\")
$path_ngx = IniRead($cfg_ini, "GENERAL", "ngx", $path_dir   & "nginx\")
$path_cli = IniRead($cfg_ini, "GENERAL", "cli", $path_dir   & "conemu\")
$path_ftp = IniRead($cfg_ini, "GENERAL", "ftp", $path_dir   & "slimftpd\")
$path_hst = IniRead($cfg_ini, "GENERAL", "hst", @windowsdir & "\system32\drivers\etc\hosts")

;
$auto_ftp = IniRead($cfg_ini, "GENERAL", "auto_ftp", "on")
;прописываем путьи
EnvSet("ROOT_DIR", $path_cli)
EnvSet("ROOT_CLI", $path_ngx)
EnvSet("ROOT_PHP", $path_php)
EnvSet("ROOT_SQL", $path_sql)
EnvSet("ROOT_GIT", $path_git)
EnvSet("ROOT_NGX", $path_ngx)
EnvSet("ROOT_FTP", $path_ftp)
;добовляем все пути к программам в переменную %PATH%
;EnvSet("PATH", $path_cli & ";" & $path_php & ";" & $path_ngx & ";" & $path_sql & ";" & $path_ftp & ";" & EnvGet("PATH"))
EnvSet("path", EnvGet("path") & ";" & $path_cli & ";" & $path_php & ";" & $path_ngx & ";" & $path_sql & ";" & $path_ftp & ";" & $path_git)
EnvUpdate()

;уст. нач. состояние
Func status_ico_stop()
    $f_ico = False
    TraySetIcon(@ScriptFullPath, 202)
EndFunc

Func t_Options()
    $opt_sync = 1
EndFunc
Func t_Reboot()
    $rbt_sync = 1
EndFunc
Func t_Quit()
    $qut_sync = 1
EndFunc
Func t_Run()
    $cmd_sync = 1
EndFunc

;запуск SQL-сервера
Func start_sql_server()
    ;проверяем путь исполняемого файла
	If Not FileExists($path_sql & "mysqld.exe") Then
        MsgBox(0, "Ошибка!", "Не найден: " & $path_sql & "mysqld.exe!")
		Exit
	EndIf
	;проверяем на отсутствие запущенных копий
	If ProcessWaitClose($exe_sql, 10) Then
	    ;запускаем SQL-сервер
		If Run("mysqld.exe --defaults-file=""..\my.ini""", $path_sql, @SW_HIDE) > 0 Then
			FileWrite($log_fle, $CRDATE & ': Запущен SQL-сервер' & @CRLF)
		Else
			FileWrite($log_fle, $CRDATE & ': Не удалось запустить SQL-сервер!' & @CRLF)
		EndIf
	Else
		FileWrite($log_fle, $CRDATE & ': SQL-сервер не был запущен т.к. не закрыт предыдущий процесс!' & @CRLF)
	EndIf
EndFunc

;закрываем SQL-сервера
Func stop_sql_server()
	For $ps_cnt = 0 To 100
		$ps_pid = ProcessExists($exe_sql)
		If $ps_pid Then
			If ProcessClose($ps_pid) Then
			    FileWrite($log_fle, $CRDATE & ': Завершен (MySQL) процес с PID = ' & $ps_pid & @CRLF)
			EndIf
		Else
			ExitLoop
		EndIf
	Next
	;проверка результата работы цикла завершающего все предыдущие процессы
	If ProcessExists ($exe_sql) Then
		FileWrite($log_fle, $CRDATE & ': SQL-сервер остановить не удалось!' & @CRLF)
	Else
		FileWrite($log_fle, $CRDATE & ': SQL-сервер остановлен' & @CRLF)
	EndIf
EndFunc

;запуск сервера NGINX
Func start_nginx_server()
    ;проверяем путь исполняемого файла
	If Not FileExists($path_ngx & "nginx.exe") Then
        MsgBox(0, "Ошибка!", "Не найден: " & $path_ngx & "nginx.exe!")
		Exit
	EndIf
	;проверяем на отсутствие запущенных копий
	If ProcessWaitClose($exe_ngx, 10) Then
	    ;запускаем nginx сервер
		If Run("nginx.exe" & $root_dir, $path_ngx, @SW_HIDE) > 0 Then
			FileWrite($log_fle, $CRDATE & ': Запущен сервер NGINX' & @CRLF)
		Else
			FileWrite($log_fle, $CRDATE & ': Не удалось запустить NGINX сервер!' & @CRLF)
		EndIf
	Else
		FileWrite($log_fle, $CRDATE & ': Сервер NGINX не был запущен т.к. не закрыт предыдущий процесс!' & @CRLF)
	EndIf
EndFunc

;закрываем сервер NGINX
Func stop_nginx_server()
	For $ps_cnt = 0 To 100
		$ps_pid = ProcessExists($exe_ngx)
		If $ps_pid Then
			If ProcessClose($ps_pid) Then
			    FileWrite($log_fle, $CRDATE & ': Завершен (NGINX) процес с PID = ' & $ps_pid & @CRLF)
			EndIf
		Else
			ExitLoop
		EndIf
	Next
	;проверка результата работы цикла завершающего все предыдущие процессы
	If ProcessExists ($exe_ngx) Then
		FileWrite($log_fle, $CRDATE & ': Сервер NGINX остановить не удалось!' & @CRLF)
	Else
		FileWrite($log_fle, $CRDATE & ': Сервер NGINX остановлен' & @CRLF)
	EndIf
EndFunc

;запуск PHP-сервера
Func start_php_server()
    ;проверяем путь исполняемого файла
    If Not FileExists($path_php & "php-cgi.exe") Then
        MsgBox(0, "Ошибка!", "Не найден: " & $path_php & "php-cgi.exe!")
		Exit
	EndIf
	If ProcessWaitClose($exe_php, 10) Then
	    ;запускаем php сервер
		If Run("php-cgi -b 127.0.0.1:9000", $path_php, @SW_HIDE) > 0 Then
			FileWrite($log_fle, $CRDATE & ': Запущен PHP-сервер' & @CRLF)
		Else
			FileWrite($log_fle, $CRDATE & ': Не удалось запустить PHP сервер!' & @CRLF)
		EndIf
	Else
		FileWrite($log_fle, $CRDATE & ': Сервер PHP не был запущен т.к. не закрыт предыдущий процесс!' & @CRLF)
	EndIf
EndFunc

;закрываем PHP-сервер
Func stop_php_server()
    ;закрываем PHP-сервер
	For $ps_cnt = 0 To 100
		$ps_pid = ProcessExists($exe_php)
		If $ps_pid Then
			If ProcessClose($ps_pid) Then
			    FileWrite($log_fle, $CRDATE & ': Завершен (PHP) процес с PID = ' & $ps_pid & @CRLF)
			EndIf
		Else
			ExitLoop
		EndIf
	Next
	;проверка результата работы цикла завершающего все предыдущие процессы
	If ProcessExists ($exe_php) Then
		FileWrite($log_fle, $CRDATE & ': Сервер PHP остановить не удалось!' & @CRLF)
	Else
		FileWrite($log_fle, $CRDATE & ': Сервер PHP остановлен' & @CRLF)
	EndIf
EndFunc

; запускаем терминал
Func _Run()
	If @OSArch = 'X86' Then
	    Run("ConEmu.exe", $path_dir, @SW_SHOW)
	Else
	    Run("ConEmu64.exe", $path_dir, @SW_SHOW)
	EndIf
EndFunc

;деактивируем меню управления ftp-сервером
Func off_ftp_state($state = 1)
	TrayItemSetState($ftp_start, $TRAY_DISABLE)
	TrayItemSetState($ftp_stop,  $TRAY_DISABLE)
	TrayItemSetState($ftp_reset, $TRAY_DISABLE)
	;включаем принудительное обновление состояния
	If $state Then
	    $ftp_state = 0
	EndIf
EndFunc

;обновляем состояние меню ftp-сервера
Func test_ftp_state()
    If ProcessExists($exe_ftp) Then
	    If $ftp_state = 0 OR $ftp_state = 1 Then
			off_ftp_state(0)
			TrayItemSetState($ftp_stop,  $TRAY_ENABLE)
			TrayItemSetState($ftp_reset, $TRAY_ENABLE)
			$ftp_state = 2
		EndIf
	Else
	    If $ftp_state = 0 OR $ftp_state = 2 Then 
			off_ftp_state(0)
			TrayItemSetState($ftp_start, $TRAY_ENABLE)
			$ftp_state = 1
		EndIf
	EndIf
EndFunc

;запуск FTP-сервера
Func start_ftp_server()
    off_ftp_state()
    ;проверяем путь исполняемого файла
    If Not FileExists($path_ftp & "slimftpd.exe") Then
        MsgBox(0, "Ошибка!", "Не найден: " & $path_ftp & "slimftpd.exe!")
		Exit
	EndIf
	If ProcessWaitClose($exe_ftp, 10) Then
	    ;запускаем ftp сервер
		If Run("slimftpd", $path_ftp, @SW_HIDE) > 0 Then
			FileWrite($log_fle, $CRDATE & ': Запущен FTP-сервер' & @CRLF)
		Else
			FileWrite($log_fle, $CRDATE & ': FTP-сервер запустить не удалось!' & @CRLF)
		EndIf
	Else
		FileWrite($log_fle, $CRDATE & ': FTP-сервер не был запущен т.к. не закрыт предыдущий процесс!' & @CRLF)
	EndIf
EndFunc

;закрываем FTP-сервер
Func stop_ftp_server()
    off_ftp_state()
	;закрываем PHP-сервер
	For $ps_cnt = 0 To 100
		$ps_pid = ProcessExists($exe_ftp)
		If $ps_pid Then
			If ProcessClose($ps_pid) Then
			    FileWrite($log_fle, $CRDATE & ': Завершен (FTP) процес с PID = ' & $ps_pid & @CRLF)
			EndIf
		Else
			ExitLoop
		EndIf
	Next
	;проверка результата работы цикла завершающего все предыдущие процессы
	If ProcessExists ($exe_php) Then
		FileWrite($log_fle, $CRDATE & ': FTP-сервер остановить не удалось!' & @CRLF)
	Else
		FileWrite($log_fle, $CRDATE & ': FTP-сервер остановлен' & @CRLF)
	EndIf
EndFunc

Func reset_ftp_server()
    off_ftp_state()
    stop_ftp_server()
	Sleep(1000)
	start_ftp_server()
EndFunc

Func _Options()
	Msgbox(64,"Preferences:","OS:" & @OSVersion)
EndFunc

Func _Reboot()
    status_ico_stop()
    stop_php_server()
	stop_sql_server()
	stop_nginx_server()
	;reset_ftp_server()
	update_hosts($path_hst)
	start_php_server()
	start_sql_server()
	start_nginx_server()
EndFunc

;завершение работы...
Func _Quit()
    status_ico_stop()
	stop_nginx_server()
	stop_sql_server()
	stop_php_server()
	stop_ftp_server()
    ;закрываем лог
    FileWrite($log_fle, $CRDATE & ': Завершение программы...' & @CRLF)
    FileClose($log_fle)
    Exit
EndFunc   ;==>Exit1

;уст. нач. значение
status_ico_stop()
;автозапус ftp-сервера
If $auto_ftp = "on" Then
   reset_ftp_server()
EndIf

;обновляем hosts-файл
update_hosts($path_hst)

While 1
    test_ftp_state()
    ; выясняем состояние процессов
    $f_php = ProcessExists($exe_php)
    $f_ngx = ProcessExists($exe_ngx)
    $f_sql = ProcessExists($exe_sql)
	;меняем иконку в трее
	If $f_php AND $f_ngx AND $f_sql Then
		If Not $f_ico Then
			TraySetIcon(@ScriptFullPath, 201)
			$f_ico = True
		EndIf
	Else
		If $f_ico Then
			TraySetIcon(@ScriptFullPath, 202)
			$f_ico = False
		EndIf
	EndIf
	;отслеживаем работу серверов и в случае падения перезапускаем
	If $sync_delay > 0 Then
		$sync_delay = $sync_delay - 1
	Else
		If Not $f_php Then
			FileWrite($log_fle, $CRDATE & ': Процесс PHP-сервера не обнаружен!' & @CRLF)
			start_php_server()
		EndIf
		If Not $f_ngx Then
			FileWrite($log_fle, $CRDATE & ': Процесс сервера NGINX не обнаружен!' & @CRLF)
			start_nginx_server()
		EndIf
		If Not $f_sql Then
			FileWrite($log_fle, $CRDATE & ': Процесс SQL-сервера не обнаружен!' & @CRLF)
			start_sql_server()
		EndIf
		$sync_delay = 100
	EndIf
	; синхронизируем работу цикла и обработчики событий
	If   $qut_sync = 1   Then
	    _Quit()
	    $qut_sync = 0
	ElseIf $rbt_sync = 1 Then
	    _Reboot()
	    $rbt_sync = 0
	ElseIf $opt_sync = 1 Then
	    _Options()
	    $opt_sync = 0
	ElseIf $cmd_sync = 1 Then
	    _Run()
	    $cmd_sync = 0	
	EndIf
	Sleep(100)
WEnd