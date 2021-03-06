﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=6.51
@EndOfDesignText@
'Static code module
Sub Process_Globals
	Private fx As JFX
End Sub

Sub createWorkFile(filename As String,path As String,sourceLang As String)
	Dim workfile As Map
	workfile.Initialize
	workfile.Put("filename",filename)
	
	Dim sourceFiles As List
	sourceFiles.Initialize
	
	Dim files As List
	files=getFilesList(XMLUtils.escapedText(File.ReadString(File.Combine(path,"source"),filename),"source","xliff"))
	
	For Each fileMap As Map In files
		Try
			Dim body As Map
			body=fileMap.Get("body")
		Catch
			Continue
		End Try
		Dim sourceFileMap As Map
		sourceFileMap.Initialize
		Dim segmentsList As List
		segmentsList.Initialize
		Dim attributes As Map
		attributes=fileMap.Get("Attributes")
		Dim innerfileName As String
		innerfileName=attributes.Get("original")
		
		For Each tu As List In getTransUnits(fileMap)
			Dim inbetweenContent As String=""
			Dim text As String
			text=tu.Get(0)
			Dim id As String
			id=tu.Get(1)
			Dim index As Int=-1
			Dim segmentedText As List
			segmentedText=segmentation.segmentedTxt(text,False,sourceLang,path)
			For Each source As String In segmentedText
				Log("source"&source)
				index=index+1
				Dim bitext As List
				bitext.Initialize
				If source.Trim="" And index<>segmentedText.Size-1 Then 'newline or empty space
					inbetweenContent=inbetweenContent&source
					Continue
				else if filterGenericUtils.tagsRemovedText(source).Trim="" And index<>segmentedText.Size-1 Then
					inbetweenContent=inbetweenContent&source
					Continue
				Else
					Dim sourceShown As String=source
					If filterGenericUtils.tagsNum(sourceShown)=1 Then
						sourceShown=filterGenericUtils.tagsAtBothSidesRemovedText(sourceShown)
					End If
					If filterGenericUtils.tagsNum(sourceShown)=2 And Regex.IsMatch("<.*?>",sourceShown) Then
						sourceShown=filterGenericUtils.tagsAtBothSidesRemovedText(sourceShown)
					End If

					bitext.add(sourceShown.Trim)
					bitext.Add("")
					bitext.Add(inbetweenContent&source) 'inbetweenContent contains crlf and spaces between sentences
					bitext.Add(innerfileName)
					Dim extra As Map
					extra.Initialize
					extra.Put("id",id)
					bitext.Add(extra)
					inbetweenContent=""

				End If
				If index=segmentedText.Size-1 And filterGenericUtils.tagsRemovedText(sourceShown).Trim="" And segmentsList.Size>0 Then 'last segment contains tags but no text
					Dim previousBitext As List
					previousBitext=segmentsList.Get(segmentsList.Size-1) 
					Dim previousExtra As Map
					previousExtra=previousBitext.Get(4) 'segments is at file level not trans-unit level, so needs verification
					If previousExtra.Get("id")=id Then
						Dim sourceShown As String
						sourceShown=previousBitext.Get(0)&source.Trim
						If filterGenericUtils.tagsNum(sourceShown)=1 Then
							sourceShown=filterGenericUtils.tagsAtBothSidesRemovedText(sourceShown)
						End If
						If filterGenericUtils.tagsNum(sourceShown)=2 And Regex.IsMatch("<.*?>",sourceShown) Then
							sourceShown=filterGenericUtils.tagsAtBothSidesRemovedText(sourceShown)
						End If
						previousBitext.Set(0,sourceShown)
						previousBitext.Set(2,previousBitext.Get(2)&bitext.Get(2))
						inbetweenContent=""
					End If
				Else if segmentsList.Size=0 And filterGenericUtils.tagsRemovedText(sourceShown).trim="" Then
					Continue
				Else
					segmentsList.Add(bitext)
				End If
				
			Next
		Next
		If segmentsList.Size<>0 Then
			sourceFileMap.Put(innerfileName,segmentsList)
			sourceFiles.Add(sourceFileMap)
		End If
	Next

	workfile.Put("files",sourceFiles)
	
	Dim json As JSONGenerator
	json.Initialize(workfile)
	File.WriteString(File.Combine(path,"work"),filename&".json",json.ToPrettyString(4))
End Sub




Sub getTransUnits(fileMap As Map) As List
	Dim body As Map
	body=fileMap.Get("body")
	Dim tidyTransUnits As List
	tidyTransUnits.Initialize
	Dim transUnits As List
	transUnits=XMLUtils.GetElements(body,"trans-unit")
	For Each transUnit As Map In transUnits
		Log(transUnit)
		Dim attributes As Map
		attributes=transUnit.Get("Attributes")
		Dim id As String
		id=attributes.Get("id")
		Try
			Dim source As Map
			source=transUnit.Get("source")
			Dim text As String
			text=source.Get("Text")
		Catch
			Log(LastException)
			Dim text As String
			text=transUnit.Get("source")
		End Try

		Dim oneTransUnit As List
		oneTransUnit.Initialize
		oneTransUnit.Add(text)
		oneTransUnit.Add(id)
		tidyTransUnits.Add(oneTransUnit)
	Next
	Return tidyTransUnits
End Sub

Sub getFilesList(xmlstring As String) As List
	Log("read")
	Dim xmlMap As Map
	xmlMap=XMLUtils.getXmlMap(xmlstring)
	Log(xmlMap)
	Dim xliffMap As Map
	xliffMap=xmlMap.Get("xliff")
	Return XMLUtils.GetElements(xliffMap,"file")
End Sub


Sub generateFile(filename As String,path As String,projectFile As Map)
	Dim workfile As Map
	Dim json As JSONParser
	json.Initialize(File.ReadString(File.Combine(path,"work"),filename&".json"))
	workfile=json.NextObject
	Dim sourceFiles As List
	sourceFiles=workfile.Get("files")
	Dim translationMap As Map
	translationMap.Initialize
	For Each sourceFileMap As Map In sourceFiles
		Dim innerfilename As String
		innerfilename=sourceFileMap.GetKeyAt(0)
		Dim segmentsList As List
		segmentsList=sourceFileMap.Get(innerfilename)
		Dim index As Int=-1
		For Each bitext As List In segmentsList
			index=index+1
			Dim source,target,fullsource,translation As String
			source=bitext.Get(0)
			target=bitext.Get(1)
			fullsource=bitext.Get(2)
			'Log(source)
			'Log(target)
			'Log(fullsource)
			If target="" Then
				translation=fullsource
			Else
				If shouldAddSpace(projectFile.Get("source"),index,segmentsList) Then
					target=target&" "
				End If
				target=addNecessaryTags(target,source)
				translation=fullsource.Replace(source,target)
			End If
			Dim extra As Map
			extra=bitext.Get(4)
			If extra.ContainsKey("translate") Then
				If extra.get("translate")="no" Then
					translation=fullsource.Replace(source,"")
				End If
			End If

			If translationMap.ContainsKey(extra.Get("id")) Then
				Dim dataMap As Map
				dataMap=translationMap.Get(extra.Get("id"))
				translation=dataMap.Get("translation")&translation
				translationMap.put(extra.Get("id"),CreateMap("translation":translation,"filename":innerfilename))
			Else
				translationMap.put(extra.Get("id"),CreateMap("translation":translation,"filename":innerfilename))
			End If
		Next
	Next
	Dim xmlString As String
	xmlString=XMLUtils.getXmlFromMap(insertTranslation(translationMap,filename,path))
	xmlString=XMLUtils.unescapedText(xmlString,"source","xliff")
	xmlString=XMLUtils.unescapedText(xmlString,"target","xliff")
	Log(xmlString)
	File.WriteString(File.Combine(path,"target"),filename,xmlString)
	Main.updateOperation(filename&" generated!")
End Sub

Sub insertTranslation(translationMap As Map,filename As String,path As String) As Map
	Dim xmlstring As String
	xmlstring=File.ReadString(File.Combine(path,"source"),filename)
	xmlstring=XMLUtils.escapedText(xmlstring,"source","xliff")
	xmlstring=XMLUtils.escapedText(xmlstring,"target","xliff")
	Log("xml"&xmlstring)
	Dim xmlMap As Map
	xmlMap=XMLUtils.getXmlMap(xmlstring)
	Log("map"&xmlMap)
	Dim xliffMap As Map
	xliffMap=xmlMap.Get("xliff")
	Dim filesList As List
	filesList=XMLUtils.GetElements(xliffMap,"file")
	For Each innerFile As Map In filesList
		Dim body As Map
		Try
			body=innerFile.Get("body")
		Catch
			Log(LastException)
			Continue
		End Try
		Dim fileAttributes As Map
		fileAttributes=innerFile.Get("Attributes")
		Dim originalFilename As String
		originalFilename=fileAttributes.Get("original")
		Dim transUnits As List
		transUnits=XMLUtils.GetElements(body,"trans-unit")
		For Each transUnit As Map In transUnits
			Dim attributes As Map
			attributes=transUnit.Get("Attributes")
			Dim id As String
			id=attributes.Get("id")
			Dim target As Map
			target=transUnit.Get("target")
			If translationMap.ContainsKey(id) Then
				Dim dataMap As Map
				dataMap=translationMap.Get(id)
				If originalFilename=dataMap.Get("filename") Then
					For Each key As String In target.Keys
						If key<>"Attributes" Then
							target.Remove(key)
						End If
					Next
					If target.ContainsKey("Text") Then
						target.Remove("Text")
					End If
					target.Put("Text",dataMap.Get("translation"))
					Log(dataMap.Get("translation"))
				End If
			End If
		Next

		body.Put("trans-unit",transUnits)
	Next

	xliffMap.Put("file",filesList)
	xmlMap.Put("xliff",xliffMap)
	Log(xmlMap)
	Return xmlMap
End Sub

Sub addNecessaryTags(target As String,source As String) As String
	Dim tagMatcher As Matcher
	tagMatcher=Regex.Matcher2("<.*?>",32,source)
	Dim tagsList As List
	tagsList.Initialize
	Do While tagMatcher.Find
		tagsList.Add(tagMatcher.Match)
	Loop
	Dim tagMatcher As Matcher
	tagMatcher=Regex.Matcher2("<.*?>",32,target)
	Do While tagMatcher.Find
		If tagsList.IndexOf(tagMatcher.Match)<>-1 Then
			tagsList.RemoveAt(tagsList.IndexOf(tagMatcher.Match))
		End If
	Loop
	For Each tag As String In tagsList
		target=target&tag
	Next
	Return target
End Sub


Sub shouldAddSpace(sourceLang As String,index As Int,segmentsList As List) As Boolean
	Dim bitext As List=segmentsList.Get(index)
	Dim fullsource As String=bitext.Get(2)
	fullsource=Utils.getPureTextWithoutTrim(fullsource)
	Dim extra As Map
	extra=bitext.Get(4)
	Dim id As String=extra.Get("id")
	If sourceLang="zh" Then
		If index+1<=segmentsList.Size-1 Then
			Dim nextBitext As List
			nextBitext=segmentsList.Get(index+1)
			Dim nextfullsource As String=nextBitext.Get(2)
			nextfullsource=Utils.getPureTextWithoutTrim(nextfullsource)
			Dim nextExtra As Map=nextBitext.Get(4)
			Dim nextid As String=nextExtra.Get("id")
			If nextid=id Then
				Try
					If Regex.IsMatch("\s",nextfullsource.CharAt(0))=False And Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1))=False Then
						Return True
					End If
				Catch
					Log(LastException)
				End Try
			End If
		End If
	End If
	Return False
End Sub

Sub mergeSegment(sourceTextArea As TextArea)
	Dim index As Int
	index=Main.editorLV.GetItemFromView(sourceTextArea.Parent)
	If index+1>Main.currentProject.segments.Size-1 Then
		Return
	End If
	Dim bitext,nextBiText As List
	bitext=Main.currentProject.segments.Get(index)
	nextBiText=Main.currentProject.segments.Get(index+1)
	Dim source,nextsource As String
	source=bitext.Get(0)
	nextsource=nextBiText.Get(0)
	Dim fullsource,nextFullSource As String
	fullsource=bitext.Get(2)
	nextFullSource=nextBiText.Get(2)
	
	If bitext.Get(3)<>nextBiText.Get(3) Then
		fx.Msgbox(Main.MainForm,"Cannot merge segments as these two belong to different files.","")
		Return
	End If
	Dim extra As Map
	extra=bitext.Get(4)
	Dim nextExtra As Map
	nextExtra=nextBiText.Get(4)
	If extra.Get("id")<>nextExtra.Get("id") Then
		fx.Msgbox(Main.MainForm,"Cannot merge segments as these two belong to different trans-units.","")
		Return
	End If
		
	Dim showTag As Boolean=False
	If filterGenericUtils.tagsNum(source&nextsource)<>filterGenericUtils.tagsNum(fullsource&nextFullSource) And filterGenericUtils.tagsNum(fullsource&nextFullSource)>0 Then
		Dim result As Int
		result=fx.Msgbox2(Main.MainForm,"Segments contain unshown tags, continue?","","Yes","Cancel","No",fx.MSGBOX_CONFIRMATION)
		Log(result)
		'yes -1, no -2, cancel -3
		Select result
			Case -1
				showTag=True
			Case -2
				Return
			Case -3
				Return
		End Select

	End If
	
	Dim pane,nextPane As Pane

	pane=Main.editorLV.GetPanel(index)
	nextPane=Main.editorLV.GetPanel(index+1)
	Dim targetTa,nextSourceTa,nextTargetTa As TextArea
	nextSourceTa=nextPane.GetNode(0)
	nextTargetTa=nextPane.GetNode(1)
		

		
	Dim sourceWhitespace,targetWhitespace,fullsourceWhitespace As String
	sourceWhitespace=""
	targetWhitespace=""
	fullsourceWhitespace=""
	
	If Main.currentProject.projectFile.Get("source")="en" Then
		If Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1)) Or Regex.IsMatch("\s",nextFullSource.CharAt(0)) Then
			sourceWhitespace=" "
		Else
			sourceWhitespace=""
		End If
	else if Main.currentProject.projectFile.Get("target")="en" Then
		targetWhitespace=" "
	End If
	
	If Main.currentProject.projectFile.Get("source")="en" Then
		If Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1)) Or Regex.IsMatch("\s",nextFullSource.CharAt(0)) Then
			fullsourceWhitespace=" "
		End If
	End If
		
	If showTag Then
		source=fullsource&nextFullSource
		If filterGenericUtils.tagsNum(source)=1 Then
			source=filterGenericUtils.tagsAtBothSidesRemovedText(source)
		End If
		If filterGenericUtils.tagsNum(source)=2 And Regex.IsMatch("<.*?>",source) Then
			source=filterGenericUtils.tagsAtBothSidesRemovedText(source)
		End If
		fullsource=fullsource&nextFullSource
	Else
		source=source.Trim&sourceWhitespace&nextSourceTa.Text.Trim
		fullsource=Utils.rightTrim(fullsource)&fullsourceWhitespace&Utils.leftTrim(nextFullSource)
	End If
	sourceTextArea.Text=source
	sourceTextArea.Tag=sourceTextArea.Text
		
	targetTa=pane.GetNode(1)
	targetTa.Text=targetTa.Text&targetWhitespace&nextTargetTa.Text


	bitext.Set(0,sourceTextArea.Text)
	bitext.Set(1,targetTa.Text)
	bitext.Set(2,fullsource)

	

		
	Main.currentProject.segments.RemoveAt(index+1)
	Main.editorLV.RemoveAt(Main.editorLV.GetItemFromView(sourceTextArea.Parent)+1)
End Sub

Sub splitSegment(sourceTextArea As TextArea)
	Dim index As Int
	index=Main.editorLV.GetItemFromView(sourceTextArea.Parent)
	Dim source As String
	Dim newSegmentPane As Pane
	newSegmentPane.Initialize("segmentPane")
	source=sourceTextArea.Text.SubString2(sourceTextArea.SelectionEnd,sourceTextArea.Text.Length)
	Dim bitext,newBiText As List
	bitext=Main.currentProject.segments.Get(index)
	If source.Trim="" Then
		Return
	End If
	
	Dim fullsource As String
	fullsource=bitext.Get(2)

	sourceTextArea.Text=sourceTextArea.Text.SubString2(0,sourceTextArea.SelectionEnd)
	sourceTextArea.Text=sourceTextArea.Text.Replace(CRLF,"")
	sourceTextArea.Tag=sourceTextArea.Text
	Main.currentProject.addTextAreaToSegmentPane(newSegmentPane,source,"")
	
	
	bitext.Set(0,sourceTextArea.Text)
	bitext.Set(2,fullsource.SubString2(0,fullsource.IndexOf(sourceTextArea.Text)+sourceTextArea.Text.Length))
	
	
	newBiText.Initialize
	newBiText.Add(source)
	newBiText.Add("")
	newBiText.Add(fullsource.SubString2(fullsource.IndexOf(sourceTextArea.Text)+sourceTextArea.Text.Length,fullsource.Length))
	newBiText.Add(bitext.Get(3))
	newBiText.Add(bitext.Get(4))
	Main.currentProject.segments.set(index,bitext)
	Main.currentProject.segments.InsertAt(index+1,newBiText)


	Main.editorLV.InsertAt(Main.editorLV.GetItemFromView(sourceTextArea.Parent)+1,newSegmentPane,"")
End Sub

Sub previewText As String
	Dim text As String
	If Main.editorLV.Size<>Main.currentProject.segments.Size Then
		Return ""
	End If
	Dim previousID As String=""
	For i=Max(0,Main.currentProject.lastEntry-3) To Min(Main.currentProject.lastEntry+7,Main.currentProject.segments.Size-1)

		Dim p As Pane
		p=Main.editorLV.GetPanel(i)
		If p.NumberOfNodes=0 Then
			Continue
		End If
		Dim sourceTextArea As TextArea
		Dim targetTextArea As TextArea
		sourceTextArea=p.GetNode(0)
		targetTextArea=p.GetNode(1)
		Dim bitext As List
		bitext=Main.currentProject.segments.Get(i)
		Dim source,target,fullsource,translation As String
		source=sourceTextArea.Text
		target=targetTextArea.Text
		fullsource=bitext.Get(2)
		Dim extra As Map
		extra=bitext.Get(4)

		If target="" Then
			translation=fullsource
		Else
			If shouldAddSpace(Main.currentProject.projectFile.Get("source"),i,Main.currentProject.segments) Then
				target=target&" "
			End If
			translation=fullsource.Replace(source,target)
		End If

		Dim id As String
		id=extra.Get("id")
		If previousID<>id Then
			text=text&CRLF
			previousID=id
		End If
		If i=Main.currentProject.lastEntry Then
			translation=$"<span id="current" name="current" >${translation}</span>"$
		End If
		text=text&translation
	Next
	Return text
End Sub