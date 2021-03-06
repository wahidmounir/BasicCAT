﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=6.51
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private frm As Form
	Private paramsTableView As TableView
	Private params As Map
	Private originalParams As Map
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(engineName As String,preferencesMap As Map)
	frm.Initialize("frm",300,300)
	frm.RootPane.LoadLayout("mtparamfiller")
	params.Initialize
	originalParams.Initialize

	Dim mtmap As Map
	mtmap.Initialize
	If preferencesMap.ContainsKey("mt") Then
		mtmap=preferencesMap.Get("mt")
		If mtmap.ContainsKey(engineName) Then
			params=mtmap.Get(engineName)
			' should not use originalParams=params
			For Each key As String In params.Keys
				originalParams.Put(key,params.Get(key))
			Next
		End If
	End If
	init(engineName)
End Sub

Public Sub showAndWait As Map
    frm.ShowAndWait
	Return params
End Sub

Sub init(engineName As String)
	Select engineName
		Case "baidu"
			setTableView(Array As String("appid","key"))
		Case "yandex"
			setTableView(Array As String("key"))
		Case "youdao"
			setTableView(Array As String("appid","key"))
		Case "google"
			setTableView(Array As String("key"))
		Case "microsoft"
			setTableView(Array As String("key"))
		Case "mymemory"
			setTableView(Array As String("email"))
	End Select
	If MT.getMTPluginList.IndexOf(engineName)<>-1 Then
		wait for (Main.plugin.RunPlugin(engineName&"MT","getParams",Null)) complete (result As List)
		setTableView(result)
	End If
End Sub

Sub setTableView(paramsList As List)
	paramsTableView.SetColumns(Array As String("param","value"))
	For Each item As String In paramsList
		Dim Row1() As Object
		If params.ContainsKey(item) Then
			Row1=Array (item, params.Get(item))
		Else
			Row1=Array (item, "")
		End If
		paramsTableView.Items.Add(Row1)
		params.Put(Row1(0),Row1(1))
	Next
End Sub

Sub cancelButton_MouseClicked (EventData As MouseEvent)
	params=originalParams
	frm.Close
End Sub

Sub SaveButton_MouseClicked (EventData As MouseEvent)
	frm.Close
End Sub

Sub paramsTableView_MouseClicked (EventData As MouseEvent)
	If paramsTableView.SelectedRowValues<>Null Then
		Dim inpBox As InputBox
		inpBox.Initialize
		Dim row() As Object
		row=paramsTableView.Items.Get(paramsTableView.SelectedRow)
		row(1)=inpBox.showAndWait
		paramsTableView.Items.Set(paramsTableView.SelectedRow,row)
		params.Put(paramsTableView.SelectedRowValues(0),row(1))
	End If
End Sub