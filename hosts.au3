#include <ListBoxConstants.au3>
#include <GUIConstantsEx.au3>
#Include <Array.au3>
#include <File.au3>

;Dim $path = "c:\Windows\system32\drivers\etc\hosts"
;Dim $server_ip = "127.0.0.1"

;обновляем hosts-файл
Func update_hosts($path, $server_ip = "127.0.0.1")

    Local $rec_host
	Local $rec_dirs

	Local $pattern  = "^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.+)\s*$"
	Local $arr_ix   = 0        ;индекс для циклов
	Local $arr_ip[0] ;список IP-шников из hosts
	Local $arr_rm[0] ;что нужно удалить
	Local $arr_ds[0] ;список каталогов
	Local $arr_ad[0] ;что нужно добавить
	Local $arr_md[0] ;что нужно изменить (ip)
	Local $var

	;считываем содержимое hosts-файла
	If Not _FileReadToArray($path, $rec_host) Then
	    MsgBox(0, "Ошибка!", "Не найден hosts-файл: """ & $path & """!", 8)
		Return
	EndIf
	
	For $inx = 1 To $rec_host[0]
		$var = StringRegExp($rec_host[$inx], $pattern, 1)
		If @error Then 
		    ContinueLoop
		Else
			;исключаем повторы и сохраняем адрес строки повтора
			For $inx2 = 1 To Ubound($arr_ip) 
				If Not StringCompare($arr_ip[$inx2 - 1][2], $var[1]) Then
					$len = Ubound($arr_rm) + 1
					ReDim $arr_rm[$len][3]
					$arr_rm[$len - 1][0] = $inx
					$arr_rm[$len - 1][1] = $var[0]
					$arr_rm[$len - 1][2] = $var[1]
					ContinueLoop 2
				EndIf
			Next
			;создаем список адресов из hosts-файла
			ReDim $arr_ip[$arr_ix + 1][3]
			$arr_ip[$arr_ix][0] = $inx
			$arr_ip[$arr_ix][1] = $var[0]
			$arr_ip[$arr_ix][2] = $var[1]
	        $arr_ix = $arr_ix + 1
		EndIf
	Next
	_ArraySort($arr_rm, 1, 0, (Ubound($arr_rm) - 1))
	
	;получаем список диррикторий
	$rec_dirs = _FileListToArray("c:\admin\public_html\", "*", 2)
	If Not @error Then
	    ReDim $arr_ds[$rec_dirs[0]]
		;MsgBox(4096, "test.", $rec_dirs[0])
	    For $inx = 1 To $rec_dirs[0]
		    $var = StringStripWS($rec_dirs[$inx], 3)
			$arr_ds[$inx - 1] = $var
			;создаем список того что следует добавить
			$test_bit = 0
			For $inx2 = 1 To Ubound($arr_ip) 
				If Not StringCompare($arr_ip[$inx2 - 1][2], $var) Then ;имя совпало
					$test_bit = 1
					If StringCompare($arr_ip[$inx2 - 1][1], $server_ip) Then ;ip не совпал
						; создаем массив для которых требуется изменить ip
					    $len = Ubound($arr_md) + 1
				        ReDim $arr_md[$len][3]
						$arr_md[$len - 1][0] = $arr_ip[$inx2 - 1][0]
				        $arr_md[$len - 1][1] = $arr_ip[$inx2 - 1][1] 
						$arr_md[$len - 1][2] = $arr_ip[$inx2 - 1][2] 
					EndIf			
				EndIf
			Next
			
			Switch Int($test_bit)
	            Case 1
	                ;пишем в лог сообщение
	            Case Else
	                $len = Ubound($arr_ad) + 1
				    ReDim $arr_ad[$len]
				    $arr_ad[$len - 1] = $var
	        EndSwitch
			
		Next
	EndIf
	
	;удаляем дублированные ip-адреса
	For $inx = 0 To (Ubound($arr_rm) - 1)
		_ArrayDelete($rec_host, $arr_rm[$inx][0])
	Next
	
	;изменяем существующие ip-адреса
	For $inx = 0 To (Ubound($arr_md) - 1)
		$rec_host[$arr_md[$inx][0]] = $server_ip & @TAB & $arr_md[$inx][2]
	Next
	
	;добавляем новые ip-адреса
	$rec_host_len = Ubound($rec_host)
	$arr_ad_len   = Ubound($arr_ad)
	ReDim $rec_host[$rec_host_len + $arr_ad_len]
	For $inx = 0 To ($arr_ad_len - 1)
		$rec_host[$rec_host_len + $inx] = $server_ip & @TAB & $arr_ad[$inx]
	Next
	
	;удаляем первый элемент массива перед сохранением
	_ArrayDelete($rec_host, 0)
	
	;сохраняем hosts-файл
	_FileWriteFromArray($path, $rec_host)
	
	;
	;_ArrayDisplay($rec_host, "rec_host")
	;_ArrayDisplay($arr_rm, "arr_rm")
	;_ArrayDisplay($arr_ds, "arr_ds")
	;_ArrayDisplay($arr_ip, "arr_ip")
	;_ArrayDisplay($arr_ad, "arr_ad")
	;_ArrayDisplay($arr_md, "arr_md")
EndFunc