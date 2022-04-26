<%@ Page Language="VB" MasterPageFile="~/Default.master" Title="Verificacion de empaque" %>

<%@ Import Namespace="System.Data.OleDb" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.HttpServerUtility" %>
<%@ Register TagPrefix="Club" Namespace="ClubSite" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="iTextSharp.text.pdf.BarcodeCodabar" %>
<%@ Import Namespace="System.text" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="System.Xml.XPath" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="Newtonsoft.Json" %>
<%@ Import Namespace="dllFacturaElectronica" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="dllEnvioSlackWebHook" %>
<%@ Import Namespace="Sistema" %>
<%@ Import Namespace="System.Web.Services" %>
<%@ Import Namespace="iTextSharp.text" %>
<%@ Import Namespace="iTextSharp.text.pdf" %>
<%@ Import Namespace="System.Drawing.Imaging" %>
<%@ Import Namespace="System.Drawing.Drawing2D" %>
<%@ Import Namespace="System.IO" %>
<script runat="server">

    Dim Cargar As New cargar
    Dim MyConString As String
    Dim Consulta As String
    Dim enviar As New Envio_De_Correos
    Dim CanalSistemaGuia As String
    Dim Cadenaglobal As String

    Protected Sub Page_Load(sender As Object, e As System.EventArgs)
        If Session("Usuario") Is Nothing Or Session("SmyConstring") Is Nothing Then
            Response.Redirect("Login.aspx")
        Else
            MyConString = Session("SmyConstring").ToString()
            CType(Master.FindControl("lblNombreUsuario"), Label).Text = CStr(Session("NombreUsuario"))
        End If


        If Not IsPostBack Then

            Consulta = "select 0 as CodigoDepartamento, '' as Nombre union select CodigoDepartamento, Nombre from Departamento order by Nombre"
            Cargar.CargarDDL("Nombre", "CodigoDepartamento", Consulta, DdlDepartamento, MyConString)
            Cargar.CargarDDL("Nombre", "CodigoEmpresaDeEntrega", "select 0 as CodigoEmpresaDeEntrega, '' as Nombre UNION select CodigoEmpresaDeEntrega, Nombre from EmpresaDeEntrega order by Nombre", DdlEmpresaDeEntrega, MyConString)
            Panel1.Visible = False
            Label4.Visible = False
            lblFormaDeEnvio.Visible = False
        End If
    End Sub

#Region "Functions"
    Function Llenar_DataProducto() As String
        Consulta = "" & vbLf
        Consulta += "SELECT" & vbLf
        Consulta += "  PRO.CodigoProducto," & vbLf
        Consulta += "  VEN.Cantidad," & vbLf
        Consulta += "  PRO.Nombre AS 'NombreProducto'," & vbLf
        Consulta += "  PRO.Foto" & vbLf
        Consulta += "FROM Venta AS VEN" & vbLf
        Consulta += "INNER JOIN PRODUCTO AS PRO" & vbLf
        Consulta += "  ON PRO.CodigoProducto = VEN.CodigoProducto" & vbLf
        Consulta += "WHERE VEN.CodigoFactura = " & txtCodigoFactura.Text.Trim

        Return Consulta
    End Function

    Function Llenar_DataProducto2() As String
        Consulta = "" & vbLf
        Consulta += "SELECT" & vbLf
        Consulta += "  PRO.UPC," & vbLf
        Consulta += "  VEN.CodigoVenta," & vbLf
        Consulta += "  VEN.CodigoProducto," & vbLf
        Consulta += "  VEN.Cantidad," & vbLf
        Consulta += "  VEN.EmpaqueVerificado AS Verificado," & vbLf
        Consulta += "  PRO.Nombre," & vbLf
        Consulta += "  PRO.Foto," & vbLf
        Consulta += "  VEN.Cantidad AS Escaneos," & vbLf
        Consulta += "  VEN.CodigoFactura," & vbLf
        Consulta += "  EMP.Foto AS EmpaqueRegalo" & vbLf
        Consulta += "FROM Venta AS VEN" & vbLf
        Consulta += "INNER JOIN Producto AS PRO" & vbLf
        Consulta += "  ON PRO.CodigoProducto = VEN.CodigoProducto" & vbLf
        Consulta += "INNER JOIN Factura AS FAC" & vbLf
        Consulta += "  ON FAC.CodigoFactura = VEN.CodigoFactura" & vbLf
        Consulta += "LEFT JOIN EmpaqueDeRegalo AS EMP" & vbLf
        Consulta += "  ON EMP.CodigoEmpaqueDeRegalo = VEN.CodigoEmpaqueDeRegalo" & vbLf
        Consulta += "WHERE VEN.Confirmada = 1 AND VEN.CodigoEstadoDeVenta = 1 AND VEN.CodigoFactura = " & txtCodigoFactura.Text.Trim

        Return Consulta
    End Function

    Function MostrarGenerarGuia() As Boolean
        Dim SQL As New StringBuilder
        SQL.Clear()
        SQL.AppendLine("SELECT CASE WHEN T.CantidadVenta = T.CantidaEmpaque THEN CONVERT(bit, 1) ELSE CONVERT(bit, 0) END ")
        SQL.AppendLine("FROM (SELECT COUNT(1) AS [CantidadVenta], SUM(CASE WHEN EmpaqueVerificado = 1 THEN CONVERT(int, 1) ")
        SQL.AppendLine("ELSE CONVERT(int, 0) END) AS [CantidaEmpaque] ")
        SQL.AppendLine("FROM Venta WHERE Confirmada = 1 AND CodigoFactura = " & txtCodigoFactura.Text & ") T")

        If Cargar.retornarboolean(SQL.ToString, MyConString) Then
            Panel1.Visible = True
            Label4.Visible = True
            ActualizarEmpresaEntrega(Cargar, MyConString)
        Else
            Panel1.Visible = False
            Label4.Visible = False
        End If
        Return True
    End Function

    Function VerificarGuia(ByRef ListaDeProductos As String) As Integer
        Dim CadDepartamento, CadMunicipio As String

        MyConString = Session("SmyConstring").ToString
        Dim query As String

        ListaDeProductos = ""
        If DdlDepartamento.SelectedValue = "0" Then
            Return 1
        ElseIf DdlEmpresaDeEntrega.SelectedValue = "0" Then
            Return 1
        ElseIf DdlDepartamento.SelectedValue = "1" Then
            If txtCodigoDeRastreo.Text <> "" Then
                Using mySqlConnection As New System.Data.SqlClient.SqlConnection(MyConString)
                    mySqlConnection.Open()

                    If DdlDepartamento.SelectedValue <> "0" Then
                        CadDepartamento = DdlDepartamento.SelectedValue
                    Else
                        CadDepartamento = "NULL"
                    End If
                    If DdlMunicipio.SelectedValue <> "0" Then
                        CadMunicipio = DdlMunicipio.SelectedValue
                    Else
                        CadMunicipio = "NULL"
                    End If

                    ListaDeProductos = Cargar.retornarcadena("select isnull(dbo.Lista_Valores(9,'" & txtCodigoFactura.Text & "','1','',''),'')", MyConString)
                    query = "update venta set Guia = 0 " &
                   " where CodigoFactura = " & txtCodigoFactura.Text
                    Dim mySqlCommandUpdate As New System.Data.SqlClient.SqlCommand(query, mySqlConnection)
                    Dim Filas As Integer = mySqlCommandUpdate.ExecuteNonQuery()
                    mySqlConnection.Close()
                    txtObservacionesGuia.ReadOnly = True
                    LblCodigoDeRastreo.Text = CStr(txtCodigoDeRastreo.Text)
                End Using
                Return 0
            Else
                Return 2
            End If
        Else
            If txtCodigoDeRastreo.Text <> "" Then
                Using mySqlConnection As New System.Data.SqlClient.SqlConnection(MyConString)
                    mySqlConnection.Open()

                    If DdlDepartamento.SelectedValue <> "0" Then
                        CadDepartamento = DdlDepartamento.SelectedValue
                    Else
                        CadDepartamento = "NULL"
                    End If
                    If DdlMunicipio.SelectedValue <> "0" Then
                        CadMunicipio = DdlMunicipio.SelectedValue
                    Else
                        CadMunicipio = "NULL"
                    End If

                    ListaDeProductos = Cargar.retornarcadena("select isnull(dbo.Lista_Valores(9,'" & txtCodigoFactura.Text & "','1','',''),'')", MyConString)
                    query = "update venta set   Guia = 1 " &
                   " where CodigoFactura = " & txtCodigoFactura.Text
                    Dim mySqlCommandUpdate As New System.Data.SqlClient.SqlCommand(query, mySqlConnection)
                    Dim Filas As Integer = mySqlCommandUpdate.ExecuteNonQuery()
                    mySqlConnection.Close()

                    LblCodigoDeRastreo.Text = CStr(txtCodigoDeRastreo.Text)
                End Using

                Return 0
            Else
                Return 2
            End If
        End If
    End Function

    Function Generar_Guia(ByVal DestinatarioNombre As String, ByVal DestinatarioDireccion As String, ByVal Telefono1 As String, ByVal Telefono2 As String, ByVal DestinatarioContacto As String,
        ByVal DestinatarioNit As String, ByVal CodigoPobladoDestino As String, ByVal COD As Decimal, ByRef NumeroDeGuia As String, ByRef UrlConsulta As String, ByRef MensajeError As String, ByVal IdManifiesto As String, ByVal Correlativo As Integer, ByVal Observaciones As String) As Boolean
        Dim Resultado As String
        Dim Datos As String
        Dim Exito As Boolean
        Dim Cadena As String
        Dim Consulta As String
        Dim TipoServicio As String
        Dim dtventas As New DataTable
        Dim ListaConsultas As String

        DestinatarioNombre = Replace(Replace(DestinatarioNombre, "&", "y"), "'", "")
        DestinatarioDireccion = Replace(Replace(DestinatarioDireccion, "&", "y"), "'", "")
        DestinatarioContacto = Replace(Replace(DestinatarioContacto, "&", "y"), "'", "")
        DestinatarioNit = Replace(Replace(DestinatarioNit, "&", "y"), "'", "")

        If COD = 0 Then
            TipoServicio = "1"
        Else
            TipoServicio = "3"
        End If

        If Telefono1.Contains("||") Then
            If Telefono2.Trim.Length = 0 Then
                Telefono2 = Split(Telefono1, "||")(1)
            End If
            Telefono1 = Split(Telefono1, "||")(0)
        End If

        NumeroDeGuia = "" : UrlConsulta = "" : MensajeError = ""
        ListaConsultas = ""

        Try
            Dim request As HttpWebRequest = CreateWebRequestProduccion()
            Dim soapEnvelopeXml As New XmlDocument()
            Cadena = "<?xml version=""1.0"" encoding=""utf-8""?> " & vbNewLine &
                  " <soap12:Envelope xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:soap12=""http://www.w3.org/2003/05/soap-envelope""> " & vbNewLine &
                  " <soap12:Body> " & vbNewLine &
                  " <GenerarGuia xmlns=""http://www.caexlogistics.com/ServiceBus""> " & vbNewLine &
                  " <Autenticacion> " & vbNewLine &
                  " <Login>" & System.Configuration.ConfigurationManager.AppSettings("CAEXUserLogin").ToString & "</Login> " & vbNewLine &
                  " <Password>" & System.Configuration.ConfigurationManager.AppSettings("CAEXUserPass").ToString & "</Password> " & vbNewLine &
                  " </Autenticacion> " & vbNewLine &
                  "<ListaRecolecciones> " & vbNewLine &
                   "<DatosRecoleccion> " & vbNewLine &
                   "<RecoleccionID>" & IdManifiesto & "</RecoleccionID>" & vbNewLine &
                   "<RemitenteNombre>GUATEMALA DIGITAL, S.A.</RemitenteNombre> " & vbNewLine &
                   "<RemitenteDireccion>" & Cargar.retornarcadena("select texto from mensaje where codigomensaje = 28", MyConString).ToString.Trim & "</RemitenteDireccion> " & vbNewLine &
                   "<RemitenteTelefono>24393259</RemitenteTelefono> " & vbNewLine &
                   "<DestinatarioNombre>" & DestinatarioNombre & "</DestinatarioNombre> " & vbNewLine &
                   "<DestinatarioDireccion>" & DestinatarioDireccion & "</DestinatarioDireccion> " & vbNewLine &
                   "<DestinatarioTelefono>" & Telefono1 & "</DestinatarioTelefono> " & vbNewLine &
                   "<DestinatarioContacto>" & DestinatarioContacto & "</DestinatarioContacto> " & vbNewLine

            If DestinatarioNit <> "" Then
                Cadena = Cadena & "<DestinatarioNIT>" & DestinatarioNit & "</DestinatarioNIT> " & vbNewLine
            Else
                Cadena = Cadena & "<DestinatarioNIT /> " & vbNewLine
            End If

            If Observaciones.Trim.Length > 0 Then
                Observaciones = "<Observaciones>" & Observaciones.Trim & "</Observaciones>"
            Else
                Observaciones = "<Observaciones />"
            End If

            Cadena = Cadena & "<ReferenciaCliente1>" & "Tel.:" & Telefono2 & "</ReferenciaCliente1> " & vbNewLine &
                "<ReferenciaCliente2>" & "Factura:" & txtCodigoFactura.Text & " M" & CStr(Correlativo) & "</ReferenciaCliente2> " & vbNewLine &
                 "<CodigoPobladoDestino>" & CodigoPobladoDestino & "</CodigoPobladoDestino> " & vbNewLine &
                 "<CodigoPobladoOrigen>1448</CodigoPobladoOrigen> " & vbNewLine &
                 "<TipoServicio>" & TipoServicio & "</TipoServicio> " & vbNewLine &
                 "<MontoCOD>" & CStr(COD) & "</MontoCOD> " & vbNewLine &
                "<FormatoImpresion>1</FormatoImpresion> " & vbNewLine &
                 "<CodigoCredito>0021464</CodigoCredito> " & vbNewLine &
                "<MontoAsegurado>0</MontoAsegurado> " & vbNewLine &
                Observaciones.Trim & vbNewLine &
                "<Piezas> " & vbNewLine &
                "<Pieza> " & vbNewLine &
                "<NumeroPieza>1</NumeroPieza> " & vbNewLine &
                "<TipoPieza>2</TipoPieza> " & vbNewLine &
                "<PesoPieza>10</PesoPieza> " & vbNewLine &
                "<MontoCOD>" & CStr(COD) & "</MontoCOD> " & vbNewLine &
                "</Pieza> " & vbNewLine &
                "</Piezas> " & vbNewLine &
                "</DatosRecoleccion> " & vbNewLine &
                "</ListaRecolecciones> " & vbNewLine &
                " </GenerarGuia> " & vbNewLine &
                " </soap12:Body> " & vbNewLine &
                " </soap12:Envelope>" & vbNewLine

            soapEnvelopeXml.LoadXml(Cadena)

            Guardar_Datos_Archivo_Texto("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
            Guardar_Datos_Archivo_Texto(Cadena)

            Dim stream As Stream = request.GetRequestStream()
            soapEnvelopeXml.Save(stream)
            Dim response As WebResponse = request.GetResponse()
            Dim reader As XmlReader = XmlReader.Create(response.GetResponseStream())
            Dim doc As XmlDocument = New XmlDocument()
            Dim namespaceManager As XmlNamespaceManager = New XmlNamespaceManager(doc.NameTable)
            namespaceManager.AddNamespace("soapenv", "http://www.w3.org/2003/05/soap-envelope")
            namespaceManager.AddNamespace("ns", "http://www.caexlogistics.com/ServiceBus")

            doc.Load(reader)
            Datos = doc.OuterXml

            Guardar_Datos_Archivo_Texto(Datos)

            Dim nodeList As XmlNodeList
            Dim child As XmlNode

            Resultado = ""
            nodeList = doc.DocumentElement.SelectNodes("/soapenv:Envelope/soapenv:Body/ns:GenerarGuiaResponse/ns:ResultadoGenerarGuia/ns:ResultadoOperacionMultiple/ns:ResultadoExitoso", namespaceManager)

            For Each child In nodeList
                Resultado = child.FirstChild.Value
            Next

            If UCase(Resultado) = "TRUE" Or Resultado = "1" Then
                nodeList = doc.DocumentElement.SelectNodes("/soapenv:Envelope/soapenv:Body/ns:GenerarGuiaResponse/ns:ResultadoGenerarGuia/ns:ListaRecolecciones/ns:DatosRecoleccion/*", namespaceManager)
                For Each child In nodeList
                    Select Case child.Name
                        Case "NumeroGuia"
                            If child.FirstChild IsNot Nothing Then
                                NumeroDeGuia = child.FirstChild.Value

                                ListaConsultas = ""
                                ListaConsultas += "Declare @CodigoFactura int "
                                ListaConsultas += "Declare @NumeroGuia varchar(256) "
                                ListaConsultas += "Declare @ObservacionesGuia varchar(1000) "
                                ListaConsultas += "Declare @CodigoUsuarioG int "
                                ListaConsultas += "Set @NumeroGuia = '" & NumeroDeGuia & "' "
                                ListaConsultas += "Set @CodigoFactura = " & txtCodigoFactura.Text & " "
                                ListaConsultas += "Set @ObservacionesGuia = '" & txtObservacionesGuia.Text.Trim & "' "
                                ListaConsultas += "Set @CodigoUsuarioG = " & CInt(Session("CodigoUsuario")) & " "
                                ListaConsultas += " update Venta set CodigoEstadoEntrega = 5 where CodigoEstadoDeVenta <> 2 and CodigoFactura = @CodigoFactura; "
                                ListaConsultas += " Update Factura set CodigoEmpresaDeEntrega = 2, CodigoEstadoEntregaFactura = 1, CodigoDeRastreo = @NumeroGuia, ObservacionesGuia = @ObservacionesGuia, FechaGuia = getdate(), GuiaGenerada = 1, CodigoUsuarioGuia = @CodigoUsuarioG Where CodigoFactura = @CodigoFactura; "
                                ListaConsultas += "update Cobro set COD = Case When FechaConfirmacion is null and CodigoFormaDePago = 1 Then 1 Else COD End, CodigoDeRastreo = @NumeroGuia where CodigoFactura = @CodigoFactura and Estado = 1; "

                                Guardar_Datos_Archivo_Texto("Consultas " & vbNewLine & ListaConsultas)

                                Dim Conn As SqlConnection
                                Dim myTrans As SqlTransaction

                                Conn = New SqlConnection(MyConString)

                                Conn.Open()
                                myTrans = Conn.BeginTransaction()

                                Try
                                    Cargar.insertarmodificareliminar_transaccion(ListaConsultas, Conn, myTrans)
                                    myTrans.Commit()
                                    Exito = True
                                Catch ex As Exception
                                    myTrans.Rollback()
                                    Exito = False
                                Finally
                                    Conn.Close()
                                End Try

                                If Exito = False Then
                                    System.Threading.Thread.Sleep(3000)

                                    Conn = New SqlConnection(MyConString)

                                    Conn.Open()
                                    myTrans = Conn.BeginTransaction()

                                    Try
                                        Cargar.insertarmodificareliminar_transaccion(ListaConsultas, Conn, myTrans)
                                        myTrans.Commit()
                                        Exito = True

                                    Catch ex As Exception
                                        myTrans.Rollback()
                                        AnularGuia(NumeroDeGuia, MensajeError, "SR")
                                        'MensajeError = ex.ToString
                                        MensajeError = "Error al generar la guía de Cargo Expreso, intentar generar nuevamente."
                                        Exito = False
                                    Finally
                                        Conn.Close()
                                    End Try
                                End If

                                If Exito = True Then
                                    'envio de correo estado entrega
                                    Try
                                        Consulta = "select CodigoVenta from Venta where CodigoFactura = " & txtCodigoFactura.Text.Trim
                                        Cargar.ejecuta_query_dt(Consulta, dtventas, MyConString)
                                        If dtventas.Rows.Count > 0 Then
                                            For Each fila As DataRow In dtventas.Rows
                                                If noEnviarCorreos.Checked = False Then
                                                    enviar.Enviar_Correo_Rastreo(fila("CodigoVenta").ToString, MyConString)
                                                End If
                                            Next
                                        End If
                                    Catch
                                    End Try
                                    TxtFechaGuia.Text = Date.Now.ToString("dd/MM/yyyy HH:mm:ss")
                                End If
                            Else
                                NumeroDeGuia = ""
                            End If
                        Case "URLConsulta"
                            ' ''http://wsqa.caexlogistics.com:1880/wsDataExchange/doc/VerGuiaPDF.aspx?NumeroGuia=160551437&Login=WS_GTDIG
                            If child.FirstChild IsNot Nothing Then
                                UrlConsulta = child.FirstChild.Value
                            Else
                                UrlConsulta = ""
                            End If
                    End Select
                Next
            Else
                Dim content_email As New StringBuilder
                Dim content_slack As String = "Error ocacionado al consulta la Api de Cargo Express"

                nodeList = doc.DocumentElement.SelectNodes("/soapenv:Envelope/soapenv:Body/ns:GenerarGuiaResponse/ns:ResultadoGenerarGuia/ns:ResultadoOperacionMultiple/ns:MensajeError", namespaceManager)

                MensajeError = "Mensaje Error: "
                For Each child In nodeList
                    MensajeError = MensajeError & child.FirstChild.Value + ".<br/>"
                    content_email.Append(child.FirstChild.Value + ".<br/>")
                Next

                nodeList = doc.DocumentElement.SelectNodes("/soapenv:Envelope/soapenv:Body/ns:GenerarGuiaResponse/ns:ResultadoGenerarGuia/ns:ResultadoOperacionMultiple/ns:CodigoRespuesta", namespaceManager)

                For Each child In nodeList
                    Resultado = child.FirstChild.Value
                    MensajeError = MensajeError & " Codigo respuesta = " & child.FirstChild.Value & "<br/>"

                    content_slack &= "  Código de respuesta: " & child.FirstChild.Value
                    content_email.Append("Código de respuesta: " & child.FirstChild.Value & "<br/>")
                Next

                Exito = False

                If CanalSistemaGuia <> "0" Then
                    enviar.EnvioMensajeSlack(MensajeError, "Error al generar guía", String.Empty, CanalSistemaGuia)
                End If
            End If
        Catch ex As Exception
            MensajeError = ex.ToString()
            Exito = False
        End Try
        Generar_Guia = Exito
    End Function

    Private Function getValue(ByRef list As LinkedList(Of String), ByRef matchValue As String, ByRef idx As Integer, ByRef idxMatch As Integer) As String
        If list.Count = 0 Then
            Return String.Empty
        End If

        For Each item As String In list
            Dim params As String() = item.Split(Char.Parse(";"))

            If params(idxMatch) = matchValue Then
                Return params(idx)
            End If
        Next

        Return String.Empty
    End Function

    Function verificarCobrosConfirmados() As Boolean
        'Verificar si los cobros estan confirmados
        'Esta funcion se usa para validar que los cobros esten confirmados para habilitar los botones de guardar y generar guia
        Dim checkConfirmedPayments As String
        checkConfirmedPayments = "DECLARE @Factura int SET @Factura = " & txtCodigoFactura.Text
        checkConfirmedPayments += " DECLARE @NumCobros int SELECT @NumCobros = COUNT(1) FROM Cobro WHERE Estado = 1 AND CodigoFormaDePago NOT IN (1, 3) AND CodigoFactura = @Factura"
        checkConfirmedPayments += " DECLARE @NumConfirmados int SELECT @NumConfirmados = COUNT(1) FROM Cobro WHERE Estado = 1  AND CodigoFormaDePago NOT IN (1, 3) AND FechaConfirmacion IS NOT NULL AND CodigoFactura = @Factura"
        checkConfirmedPayments += " SELECT CASE WHEN @NumCobros = @NumConfirmados THEN 1 ELSE 0 END"
        checkConfirmedPayments = CStr(Cargar.retornarentero(checkConfirmedPayments, MyConString))
        Return CBool(checkConfirmedPayments)
    End Function

    Function verificar_guia_duplicada(ByVal CGuia As String) As Boolean
        Dim existeguia = True
        Consulta = "" & vbLf
        Consulta += "SELECT" & vbLf
        Consulta += "  CAST(CASE" & vbLf
        Consulta += "    WHEN (CASE" & vbLf
        Consulta += "        WHEN n.CodigoClaseDocumento = 2 THEN SUM(n.Total)" & vbLf
        Consulta += "        ELSE CASE" & vbLf
        Consulta += "            WHEN n.CodigoClaseDocumento = 5 THEN SUM(n.ValorNeto)" & vbLf
        Consulta += "            ELSE 0" & vbLf
        Consulta += "          END" & vbLf
        Consulta += "      END)" & vbLf
        Consulta += "      = f.TotalFactura AND" & vbLf
        Consulta += "      (SELECT" & vbLf
        Consulta += "        CodigoDeRastreo" & vbLf
        Consulta += "      FROM Factura" & vbLf
        Consulta += "      WHERE CodigoFactura = f.CodigoFacturaAnulada)" & vbLf
        Consulta += "      = '" & CGuia & "'" & vbLf
        Consulta += "      THEN 1" & vbLf
        Consulta += "    ELSE 0" & vbLf
        Consulta += "  END AS bit)" & vbLf
        Consulta += "FROM Factura f" & vbLf
        Consulta += "LEFT JOIN NotaContable n" & vbLf
        Consulta += "  ON n.CodigoFactura = f.CodigoFacturaAnulada" & vbLf
        Consulta += "WHERE UsuarioAnulacion IS NULL" & vbLf
        Consulta += "AND f.CodigoFactura = " & txtCodigoFactura.Text & vbLf
        Consulta += "GROUP BY CodigoClaseDocumento," & vbLf
        Consulta += "         f.CodigoFactura," & vbLf
        Consulta += "         f.TotalFactura," & vbLf
        Consulta += "         f.CodigoFacturaAnulada" & vbLf
        Dim ExisteNota As Boolean = Cargar.retornarboolean(Consulta, MyConString)
        Consulta = "SELECT COUNT(CodigoDeRastreo) FROM Factura WHERE (FechaAnulacion is null AND CodigoEstadoFactura <> 2) and CodigoDeRastreo = '" & CGuia & "'"
        If Cargar.retornarentero(Consulta, MyConString) = 0 Or ExisteNota Then
            existeguia = False
        End If
        Return existeguia
    End Function

    Function Validar(ByVal Operacion As String) As String
        Dim DireccionEntrega As String
        Dim mensaje As String = ""

        MyConString = Session("SmyConstring").ToString

        DireccionEntrega = Cargar.retornarcadena("Select DireccionDeEntrega from Venta where CodigoFactura = " & txtCodigoFactura.Text, MyConString)

        mensaje = "Cambios guardados"
        LblRespuesta.Text = mensaje
        Return LblRespuesta.Text
    End Function

    Function Validar_Guia(ByVal GenerarGuia As Boolean) As Boolean
        Dim Exito As Boolean
        Dim Mensaje As String
        Dim WSDG As New wsGD.Service
        WSDG.Timeout = -1

        Exito = True
        Mensaje = ""
        Consulta = "select isNull(GenerarGuiaGd,0) from EmpresaDeEntrega WHERE CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue
        Dim PermisoGuia As Boolean = Cargar.retornarboolean(Consulta, MyConString)
        If Validar("Guia") <> "Cambios guardados" Then
            Exito = False
        ElseIf DdlEmpresaDeEntrega.SelectedValue = "0" Then
            LblRespuesta.Text = "Debe de ingresar empresa de entrega"
            Exito = False
        ElseIf txtCodigoFactura.Text = "0" Then
            LblRespuesta.Text = "La factura no tiene código de factura"
            Exito = False
        ElseIf DdlDepartamento.SelectedValue = "0" Then
            LblRespuesta.Text = "Debe de ingresar departamento"
            Exito = False
        ElseIf DdlMunicipio.SelectedValue = "0" Then
            LblRespuesta.Text = "Debe de ingresar municipio"
            Exito = False
        ElseIf Trim(TxtNombreCliente.Text) = "" Then
            LblRespuesta.Text = "Debe de ingresar nombre del cliente"
            Exito = False
        ElseIf Trim(TxtDireccionEntrega.Text) = "" Then
            LblRespuesta.Text = "Debe de ingresar dirección de entrega"
            Exito = False
        ElseIf Trim(TxtTelefonos.Text) = "" Then
            LblRespuesta.Text = "Debe de ingresar teléfono del cliente"
            Exito = False
        End If

        If Exito = True Then
            Dim ClaseVenta As New Clase_Venta(MyConString)
            Dim DatosGuia As New Clase_Venta.Estructura_Validar_Guia
            Dim MensajeError As String
            MensajeError = ""

            DatosGuia.Pagina = ""
            DatosGuia.EmpresaDeEntrega = DdlEmpresaDeEntrega.SelectedValue
            DatosGuia.CodigoFactura = txtCodigoFactura.Text.Trim
            DatosGuia.CodigoMunicipio = DdlMunicipio.SelectedValue
            DatosGuia.DdlRegimenDeFactura = "" ' DdlRegimenDeFactura.SelectedValue
            DatosGuia.DdlRetencion = "" ' DdlRetencion.SelectedValue

            Exito = ClaseVenta.Validar_Guia(GenerarGuia, DatosGuia, MensajeError)
            If Exito = False Then
                LblRespuesta.Text = MensajeError
            End If
        End If

        Validar_Guia = Exito
        validarBtnImprimirGuiaGT()
    End Function

    Function Suma_Cobros() As Decimal
        Dim TotalCobros, TotalCobrosSinComisiones, TotalPendiente As Decimal

        Obtener_Cobros_Factura(TotalCobros, TotalCobrosSinComisiones, TotalPendiente, "")

        Suma_Cobros = TotalCobrosSinComisiones
    End Function

    Function Suma_Seleccionadas() As Decimal
        Dim total As Decimal
        If txtCodigoFactura.Text <> "0" Then
            Consulta = "Select isnull(TotalFactura,0) from Factura where CodigoFactura = " & txtCodigoFactura.Text
            total = Cargar.retornardecimal(Consulta, MyConString)
        Else
            total = 0
        End If
        Suma_Seleccionadas = total
    End Function

    Public Function fuDevolverEstado(ByVal vGuia As String, ByRef Estado As String) As String
        Dim FechaRecibido As String = ""
        Dim cliente As New wsGD.Service
        cliente.Timeout = -1
        Dim item As New wsGD.CAEXItem
        Try
            item = cliente.fuDevolverEstado(vGuia)
            FechaRecibido = item.FechaGeneracion.ToString("yyyy/MM/dd")
            Estado = item.Estado
        Catch ex As Exception
            FechaRecibido = Date.Now.ToString("yyyy/MM/dd")
            Estado = "Error al consultar"
        End Try

        Return FechaRecibido
    End Function

    Function Validar_Ventas_Anuladas_Eliminar_Guia() As Boolean
        Dim Consulta As String
        Dim dtFacturaAnulada As New DataTable
        Dim Exito As Boolean

        Consulta = "select Count(1) from Venta where CodigoFactura = " & txtCodigoFactura.Text & " and CodigoEstadoEntrega = 6"

        If Cargar.retornarentero(Consulta, MyConString) = 0 Then
            Exito = True
        Else
            Consulta = "select CodigoEmpresaDeEntrega, CodigoDeRastreo, CodigoEstadoEntregaFactura, convert(nvarchar, FechaGuia, 121) as FechaGuia " &
            "from factura where CodigoFactura = (select CodigoFacturaAnulada from Factura Where CodigoFactura = " & txtCodigoFactura.Text & ")"

            Cargar.ejecuta_query_dt(Consulta, dtFacturaAnulada, MyConString)
            If dtFacturaAnulada.Rows.Count > 0 Then
                For Each drFacAnulada As DataRow In dtFacturaAnulada.Rows
                    If drFacAnulada("CodigoEmpresaDeEntrega").ToString = DdlEmpresaDeEntrega.SelectedValue And drFacAnulada("CodigoDeRastreo").ToString = txtCodigoDeRastreo.Text.Trim And drFacAnulada("CodigoEstadoEntregaFactura").ToString = "3" Then
                        Exito = True
                    Else
                        Exito = False
                    End If
                Next
            End If

        End If
        Validar_Ventas_Anuladas_Eliminar_Guia = Exito
    End Function

    Function AnularGuia(ByVal NumGuia As String, ByRef MensajeError As String, ByVal EstadoAnterior As String) As Boolean
        Dim Datos, Cadena As String
        Dim Exito As Boolean

        MensajeError = ""

        If EstadoAnterior = "SR" Then
            Try
                Dim request As HttpWebRequest = CreateWebRequestProduccion()
                Dim soapEnvelopeXml As New XmlDocument()
                Cadena = "<?xml version=""1.0"" encoding=""utf-8""?>" & vbNewLine &
                        " <soap12:Envelope xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:soap12=""http://www.w3.org/2003/05/soap-envelope"">" & vbNewLine &
                        " <soap12:Body>" & vbNewLine &
                        " <AnularGuia xmlns=""http://www.caexlogistics.com/ServiceBus""> " & vbNewLine &
                        " <Autenticacion> " & vbNewLine &
                        " <Login>" & System.Configuration.ConfigurationManager.AppSettings("CAEXUserLogin").ToString & "</Login> " & vbNewLine &
                        " <Password>" & System.Configuration.ConfigurationManager.AppSettings("CAEXUserPass").ToString & "</Password> " & vbNewLine &
                        " </Autenticacion> " & vbNewLine &
                        " <NumeroGuia>" & NumGuia & "</NumeroGuia> " & vbNewLine &
                        " <CodigoCredito /> " & vbNewLine &
                        " </AnularGuia> " & vbNewLine &
                        " </soap12:Body>" & vbNewLine &
                        " </soap12:Envelope>" & vbNewLine

                Guardar_Datos_Archivo_Texto("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
                Guardar_Datos_Archivo_Texto(Cadena)

                soapEnvelopeXml.LoadXml(Cadena)

                Dim stream As Stream = request.GetRequestStream()
                soapEnvelopeXml.Save(stream)
                Dim response As WebResponse = request.GetResponse()
                Dim reader As XmlReader = XmlReader.Create(response.GetResponseStream())
                Dim doc As XmlDocument = New XmlDocument()
                Dim namespaceManager As XmlNamespaceManager = New XmlNamespaceManager(doc.NameTable)
                namespaceManager.AddNamespace("soapenv", "http://www.w3.org/2003/05/soap-envelope")
                namespaceManager.AddNamespace("ns", "http://www.caexlogistics.com/ServiceBus")


                doc.Load(reader)
                Datos = doc.OuterXml

                Guardar_Datos_Archivo_Texto(Datos)

                LblRespuesta.Text = "Guia anulada"

                Exito = True

            Catch ex As Exception
                MensajeError = ex.ToString()
                Exito = False
            End Try
        Else
            Guardar_Datos_Archivo_Texto("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
            Guardar_Datos_Archivo_Texto("Se eliminó la guía " & NumGuia & " del sistema, no se hizo llamada a la Api de Cargo Expreso por que la guía se encuentra en estado " & EstadoAnterior)

            Exito = True
        End If
        AnularGuia = Exito
    End Function

    Function CreateWebRequestProduccion() As HttpWebRequest
        Dim vUrl As String = System.Configuration.ConfigurationManager.AppSettings("CargoExpresoWS").ToString
        Dim webRequest__1 As HttpWebRequest = DirectCast(WebRequest.Create(vUrl), HttpWebRequest)

        webRequest__1.Headers.Add("SOAP:Action")
        webRequest__1.ContentType = "application/soap+xml; charset=utf-8"
        webRequest__1.Accept = "text/xml"
        webRequest__1.Method = "POST"

        Return webRequest__1
    End Function
#End Region

#Region "Subs"
    Protected Sub TxtVerificaProducto_TextChanged(sender As Object, e As EventArgs)
        Dim TextBox As TextBox = CType(sender, TextBox)
        Dim row As GridViewRow = CType(TextBox.NamingContainer, GridViewRow)
        Dim UPC_correcto As String = row.Cells(0).Text.Trim().ToUpper()
        Dim string_textbox As String = TextBox.Text.Trim().ToUpper()

        If String.IsNullOrEmpty(string_textbox) Then
            Return
        End If

        If UPC_correcto.Equals(string_textbox) Then
            Dim checkbox As CheckBox = CType(row.Cells(5).Controls(0), CheckBox)

            Dim codigoVenta As String = row.Cells(6).Text.Trim()
            Dim codigoProducto As String = row.Cells(9).Text.Trim()

            ' ----------------- Verificacion_escaneos ------------------------------------
            Dim cantidadTotal As Integer = CInt(row.Cells(1).Text)
            Dim cantidadEscaneada As Integer
            Dim list As LinkedList(Of String)

            If Session("Scanners") Is Nothing Then
                list = New LinkedList(Of String)
            Else
                list = CType(Session("Scanners"), LinkedList(Of String))
            End If

            Dim foundValue As String = getValue(list, codigoVenta, 0, 1) ' e.Row.Cells(12).Text --> CodigoVenta, en el idx 0 se encuentra la cantidad escaneada

            If String.IsNullOrEmpty(foundValue) Then
                list.AddLast("1;" & codigoVenta) ' e.Row.Cells(8).Text --> CodigoVenta 
                cantidadEscaneada = 1
            Else
                cantidadEscaneada = CInt(foundValue.Trim()) + 1
                list.Remove(foundValue & ";" & codigoVenta)
                list.AddLast(CStr(cantidadEscaneada) & ";" & codigoVenta)
            End If

            Session("Scanners") = list
            row.Cells(8).Text = CStr(cantidadEscaneada) & "/" & CStr(cantidadTotal)

            ' ----------------------------------------------------------------------------

            If cantidadTotal = cantidadEscaneada Then
                Dim query As String = "UPDATE venta SET EmpaqueVerificado = 1 WHERE codigoVenta = " & codigoVenta & " AND CodigoProducto = " & codigoProducto
                Cargar.insertarmodificareliminar(query, Session("SmyConstring").ToString)

                MyConString = Session("SmyConstring").ToString()

                checkbox.Checked = True
                TextBox.Enabled = False

                LblError.ForeColor = Drawing.Color.Green
                LblError.Text = "Producto verificado Correctamente"
                LblError.Visible = True
            Else
                TextBox.Text = String.Empty
            End If
        Else
            TextBox.Text = String.Empty
            LblError.ForeColor = Drawing.Color.Red
            LblError.Text = "Código UPC '" & string_textbox & "' incorrecto"
            LblError.Visible = True
        End If
        MostrarGenerarGuia()
    End Sub

    Sub Enviar_Numero_De_Guia()
        Dim Subject, Contenido As String
        Dim Enviar As New Envio_De_Correos
        Dim paginaproducto As String
        Dim Foto As String
        Dim Prefijo, Telefono, NombreCourier As String
        Dim CadFecha As String
        Dim ListaDeProductos, CodigoProducto As String
        Dim texto(), texto2() As String
        Dim i, j As Integer
        Dim CadenaUrl As String

        If Validar("Guia") = "Cambios guardados" Then
            LblRespuesta.Text = ""
            'verifica si fue escaneado el número de guía
            If Len(Trim(txtCodigoDeRastreo.Text)) >= 15 And IsNumeric(txtCodigoDeRastreo.Text) Then '12
                'quita el último dígito, ademas lo convierte a entero para quitar los ceros al inicio
                txtCodigoDeRastreo.Text = CStr(CInt(Left(Trim(txtCodigoDeRastreo.Text), Len(Trim(txtCodigoDeRastreo.Text)) - 1)))
            End If

            ListaDeProductos = ""
            If VerificarGuia(ListaDeProductos) = 0 Then
                NombreCourier = DdlEmpresaDeEntrega.Items(DdlEmpresaDeEntrega.SelectedIndex).Text
                Dim Datos As String = Cargar.retornarcadena("Select CONCAT(isnull(Telefono,''),'|',isnull(Prefijo,'')) from EmpresaDeEntrega Where CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue, MyConString)
                Telefono = Split(Datos, "|")(0).Trim()
                Prefijo = Split(Datos, "|")(1).Trim()

                Dim ventas As String = Cargar.retornarcadena("select isnull(dbo.Lista_Valores(8,'" & txtCodigoFactura.Text & "','','',''),'')", MyConString)

                Subject = "Tu producto ha sido enviado. Código de compra: " & ventas & "."

                'Contenido = "<p>Tu producto ha sido enviado por medio de " & NombreCourier & "." & "<br/>" &
                '"Puedes rastrear tu paquete llamando al " & Telefono & " mañana a partir de las 8:00 am reportando el siguiente número de guía: " & Prefijo & txtCodigoDeRastreo.Text & "<br/>" & "<br/>"
                Contenido = Cargar.retornarcadena("select texto from mensaje where codigomensaje = 21", MyConString)
                Contenido = Contenido.Replace("@NombreCourier", NombreCourier)
                If Telefono = "" Then
                    Contenido = Contenido.Replace("Teléfono: ", Telefono)
                End If
                Contenido = Contenido.Replace("@Telefono", Telefono)
                Contenido = Contenido.Replace("@Prefijo", Prefijo)
                Contenido = Contenido.Replace("@CodigoDeRastreo", txtCodigoDeRastreo.Text)
                Contenido = Contenido.Replace("@CodigoVenta", ventas)

                Dim GuiaUrl As String = ""

                If DdlEmpresaDeEntrega.SelectedValue = "2" Then 'Unicamente cuando el codigo de empresa de entrega sea 2 (Cargo Expresso)
                    GuiaUrl = Cargar.retornarcadena("select texto from Mensaje where CodigoMensaje = 22", MyConString)
                    Dim URL As String = ""
                    URL = " https://www.cargoexpreso.com/tracking/?guia=" & txtCodigoDeRastreo.Text.Trim
                    GuiaUrl = GuiaUrl.Replace("@NombreCourier", NombreCourier)
                    GuiaUrl = GuiaUrl.Replace("@URL", URL)
                    Contenido = Contenido & GuiaUrl

                End If
                CadFecha = Cargar.retornafecha("select Fecha from Venta where CodigoFactura = " & txtCodigoFactura.Text, MyConString)

                If ListaDeProductos = "" Then
                    ListaDeProductos = Cargar.retornarcadena("select isnull(dbo.Lista_Valores(9,'" & txtCodigoFactura.Text & "','2','" & LblCodigoDeRastreo.Text & "',''),'')", MyConString)
                End If
                texto = Split(ListaDeProductos, "\\")

                ListaDeProductos = "<table border="" 1""><tr><td>Cantidad</td><td align="" center"">Nombre producto</td><td align="" center"">Foto</td></tr>"

                For i = 0 To texto.Length - 1
                    texto2 = Split(texto(i), "~~")
                    ListaDeProductos = ListaDeProductos + "<tr>"
                    ListaDeProductos = ListaDeProductos + "<td align="" center"">" + texto2(0) + "</td>"
                    ListaDeProductos = ListaDeProductos + "<td align="" left"">" + texto2(1) + "</td>"

                    CodigoProducto = texto2(2)
                    Foto = texto2(3)
                    If Trim(Foto) <> "" Then
                        If InStr(Foto, "http") = 0 Then
                            If Mid(Foto, 1, 1) <> "/" And Mid(Foto, 1, 1) <> "\" Then
                                Foto = "/" + Foto
                            End If
                            Foto = Replace(Foto, "\", "/")
                            Foto = "http://www.guatemaladigital.com/" & Foto
                        End If

                        Consulta = "select '/' + " & Cargar.Reemplazar_Cadena_Url("c.Nombre") & " + '/' + " & Cargar.Reemplazar_Cadena_Url("p.Nombre") & " + '/' from Producto p, Categoria c " &
                                   "where p.CodigoCategoria = c.CodigoCategoria " &
                                   "and p.CodigoProducto = " & CodigoProducto

                        CadenaUrl = Cargar.retornarcadena(Consulta, MyConString)
                        CadenaUrl = Cargar.Longitud_Url(CadenaUrl)

                        paginaproducto = "http://www.guatemaladigital.com" & CadenaUrl & "Producto.aspx?Codigo=" & CodigoProducto 'cargar.retornarcadena("select pagina from producto where codigoproducto = " & lblCodigoProducto.Text, MyConString)

                        ListaDeProductos = ListaDeProductos & "<td align="" center"">" & " <a href=""" & paginaproducto & """><img src=""" & Foto & """/></a></td> "
                    Else
                        ListaDeProductos = ListaDeProductos & "<td>" & "</td>"
                    End If
                    ListaDeProductos = ListaDeProductos + "</tr>"
                Next

                ListaDeProductos = ListaDeProductos + "</table>"

                Contenido = Contenido & "Datos de la compra: " & "<br/>" &
                                      "Código: " & Cargar.retornarcadena("select isnull(dbo.Lista_Valores(8,'" & txtCodigoFactura.Text & "','','',''),'')", MyConString) & "<br/>" &
                                      "Producto: <b><br/>" & ListaDeProductos & "</b><br/>" &
                                      "Fecha: " & CadFecha.Substring(8, 2) & "-" & CadFecha.Substring(5, 2) & "-" & CadFecha.Substring(0, 4) & "<br/>" &
                                      "Solicitante: " & TxtNombreCliente.Text & "<br/>" & "<br/>"

                Consulta = "" & vbLf
                Consulta += "IF (SELECT" & vbLf
                Consulta += "    COUNT(1)" & vbLf
                Consulta += "  FROM Venta v," & vbLf
                Consulta += "       Cobro c" & vbLf
                Consulta += "  WHERE v.CodigoFactura = c.CodigoFactura" & vbLf
                Consulta += "  AND v.CodigoFactura = " & txtCodigoFactura.Text.Trim & vbLf
                Consulta += "  AND c.Estado = 1)" & vbLf
                Consulta += "  > 0" & vbLf
                Consulta += "  IF (SELECT" & vbLf
                Consulta += "      COUNT(1)" & vbLf
                Consulta += "    FROM Venta v," & vbLf
                Consulta += "         Cobro c" & vbLf
                Consulta += "    WHERE v.CodigoFactura = c.CodigoFactura" & vbLf
                Consulta += "    AND v.CodigoFactura = " & txtCodigoFactura.Text.Trim & vbLf
                Consulta += "    AND c.CodigoFormaDePago = 1" & vbLf
                Consulta += "    AND c.MontoCuota >=0" & vbLf
                Consulta += "    AND c.Estado = 1)" & vbLf
                Consulta += "    > 0" & vbLf
                Consulta += "    SELECT" & vbLf
                Consulta += "      Texto" & vbLf
                Consulta += "    FROM Mensaje" & vbLf
                Consulta += "    WHERE CodigoMensaje = 15" & vbLf
                Consulta += "  ELSE" & vbLf
                Consulta += "    SELECT" & vbLf
                Consulta += "      Texto" & vbLf
                Consulta += "    FROM Mensaje" & vbLf
                Consulta += "    WHERE CodigoMensaje = 16" & vbLf
                Consulta += "ELSE" & vbLf
                Consulta += "  SELECT" & vbLf
                Consulta += "    ''" & vbLf

                Dim Mensaje = Cargar.retornarcadena(Consulta, MyConString)
                Contenido = Contenido + "<p>" & Mensaje & "</p>" & "<br/>"

                Contenido = Contenido + "<p>Gracias por comprar en GuatemalaDigital.com.</p>"
                If noEnviarCorreos.Checked = False Then
                    Enviar.Enviar_Correo(Session("CuentaCorreos").ToString(), Me.TxtCorreoCliente.Text, Subject, Contenido, "")
                End If

                Try
                    Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente("Se envió correo de la guia Cliente: " & TxtCorreoCliente.Text & " Subject: " & Subject)
                    Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente(Contenido)
                Catch ex As Exception
                End Try

                LblRespuesta.Text = "El número de guía ha sido enviado"
                Consulta = "SELECT eef.Nombre FROM Factura f INNER JOIN EstadoEntregaFactura eef ON f.CodigoEstadoEntregaFactura = eef.CodigoEstadoEntregaFactura WHERE f.CodigoFactura = " & txtCodigoFactura.Text
                lblNombreEstadoGuia.Text = Cargar.retornarcadena(Consulta, MyConString)
            Else
                If DdlDepartamento.SelectedValue = "0" Then
                    LblRespuesta.Text = "Debe de ingresar departamento"
                ElseIf DdlEmpresaDeEntrega.SelectedValue = "0" Then
                    LblRespuesta.Text = "Debe de ingresar empresa de entrega"
                ElseIf DdlDepartamento.SelectedValue = "1" Then 'txtDireccionDeEntrega.Text.Contains("Guatemala")
                    LblRespuesta.Text = "ENVIO NO PROCESADO. Debe ingresar el siguiente número de guía para envios al departamenteo de GUATEMALA según el correlativo o el mismo que el anterior si es un envío de varias ventas."
                Else
                    LblRespuesta.Text = "ENVIO NO PROCESADO. Debe ingresar el siguiente número de guía para envios al INTERIOR según el correlativo o el mismo que el anterior si es un envío de varias ventas."
                End If
                txtCodigoDeRastreo.Text = ""
                Try
                    Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente("Error: " & LblRespuesta.Text)
                Catch ex As Exception
                End Try
            End If
        Else
            txtCodigoDeRastreo.Text = ""
            Try
                Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente("Error al validar la guía")
            Catch ex As Exception
            End Try
        End If
    End Sub

    Sub Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente(ByVal Cadena As String)
        Dim key As String = "Logs/CorreosGuiasClientes" & Date.Now.Day.ToString & Date.Now.Month.ToString & ".txt"
        Dim cliente As New wsGD.Service
        Dim bucket As New wsGD.itemBucket
        Dim contenido As String = ""
        Dim bytes As Byte()

        Try
            contenido = cliente.ObtenerContenidoObjetoBucket(key, "gd-archivospaginas")
            If contenido = "" Then
                contenido = Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            Else
                contenido &= Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            End If
        Catch e As Exception
            If contenido = "" Then
                contenido = Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            End If
        End Try

        bytes = System.Text.Encoding.UTF8.GetBytes(contenido)
        Dim base64 = Convert.ToBase64String(bytes)

        bucket = cliente.uploadfileStream(key, base64, "gd-archivospaginas")
        If Not bucket.Resultado.ToString = "True" Then
            LblRespuesta.Text = "ERROR AL SUBIR ARCHIVO"
        End If
    End Sub

    Private Sub imprimirGuia()
        Dim SQL As New StringBuilder
        Dim codigoRastreo,
       destinatario,
       contacto,
       nombreDepartamento,
       nombreMunicipio,
       telefono,
       fechaHora,
       codigoFactura As String
        Dim CodigoFormaDeEnvio As Integer

        Try
            Dim bm As Drawing.Image = Nothing
            Dim f1 As Phrase = New Phrase()
            Dim imagepath As String = Server.MapPath("Images") 'path donde están las imágenes
            Dim productopath As String = Server.MapPath("Productos") 'path donde están las imágenes de los productos
            Dim rootpath As String = Server.MapPath("") 'path a la raíz del proyecto

            'Ruta en donde se guardara el archivo
            Dim ruta As String = rootpath & "\Guias\GUIAGENERADA.pdf"
            'tamanio de la guia
            Dim doc1 = New Document(New Rectangle(290.0F, 290.0F), 15, 15, 16, 13)

            Dim writer As PdfWriter = PdfWriter.GetInstance(doc1, New FileStream(ruta, FileMode.Create))

            codigoFactura = txtCodigoFactura.Text

            Dim dtCliente As New DataTable
            'Consulta a la DB donde se obtienen informacion para la guia

            SQL.Clear()
            SQL.AppendLine("SELECT")
            SQL.AppendLine("  TOP 1 UPPER(m.nombre) AS Municipio,")
            SQL.AppendLine("  UPPER(d.Nombre) AS Departamento,")
            SQL.AppendLine("  UPPER(f.CodigoDeRastreo) AS CodigoRastreo,")
            SQL.AppendLine("  UPPER(v.NombreCliente) AS NombreCliente,")
            SQL.AppendLine("  v.DireccionDeEntrega,")
            SQL.AppendLine("  v.Telefonos,")
            SQL.AppendLine("  f.codigoFactura,")
            SQL.AppendLine("  CONVERT(VARCHAR(10), GETDATE(), 103) AS Fecha,")
            SQL.AppendLine("  FORMAT(GETDATE(), 'hh:mm tt') AS hora,")
            SQL.AppendLine("  f.CodigoFactura AS Factura,")
            SQL.AppendLine("  ISNULL(MAX(f.CodigoFormaDeEnvio), 0) AS CodigoFormaDeEnvio")
            SQL.AppendLine("FROM")
            SQL.AppendLine("  Factura f")
            SQL.AppendLine("  INNER JOIN Venta v ON f.CodigoFactura = v.CodigoFactura")
            SQL.AppendLine("  INNER JOIN Municipio m ON m.CodigoMunicipio = f.CodigoMunicipio")
            SQL.AppendLine("  INNER JOIN Departamento d ON d.CodigoDepartamento = m.CodigoDepartamento")
            SQL.AppendLine("WHERE")
            SQL.AppendLine("  f.CodigoFactura = " & CInt(codigoFactura))
            SQL.AppendLine("GROUP BY")
            SQL.AppendLine("  m.Nombre,")
            SQL.AppendLine("  d.Nombre,")
            SQL.AppendLine("  f.CodigoDeRastreo,")
            SQL.AppendLine("  v.NombreCliente,")
            SQL.AppendLine("  v.DireccionDeEntrega,")
            SQL.AppendLine("  f.CodigoMunicipio,")
            SQL.AppendLine("  f.CodigoDepartamento,")
            SQL.AppendLine("  v.telefonos,")
            SQL.AppendLine("  f.codigoFactura,")
            SQL.AppendLine("  f.CodigoFormaDeEnvio")
            SQL.AppendLine("ORDER BY")
            SQL.AppendLine("  f.CodigoFormaDeEnvio DESC")

            Cargar.ejecuta_query_dt(SQL.ToString, dtCliente, MyConString)

            doc1.Open()
            Dim fotolinea As iTextSharp.text.Image = iTextSharp.text.Image.GetInstance(rootpath & "\images\logoguatemaladigital.jpg")
            Dim bc As iTextSharp.text.pdf.Barcode128 = New Barcode128()
            fotolinea.ScalePercent(35.0F)
            fotolinea.Alignment = Element.ALIGN_CENTER
            fotolinea.Alignment = Element.ALIGN_MIDDLE
            doc1.Add(fotolinea)

            Dim fuente As BaseFont = BaseFont.CreateFont(BaseFont.HELVETICA, BaseFont.WINANSI, False)
            Dim fuente16Negrita As Font = New Font(fuente, 16, iTextSharp.text.Font.BOLD, BaseColor.BLACK)

            If dtCliente.Rows.Count > 0 Then
                Dim row As DataRow = dtCliente.Rows(dtCliente.Rows.Count - 1)
                codigoRastreo = CStr(row("CodigoRastreo"))
                destinatario = CStr(row("NombreCliente"))
                contacto = destinatario & vbCrLf & CStr(row("DireccionDeEntrega"))
                nombreMunicipio = CStr(row("Municipio"))
                nombreDepartamento = CStr(row("Departamento"))
                codigoFactura = CStr(row("codigoFactura"))
                fechaHora = CStr(row("Fecha")) & " " & CStr(row("hora"))
                telefono = CStr(row("Telefonos"))
                codigoFactura = CStr(row("Factura"))
                CodigoFormaDeEnvio = CInt(row("CodigoFormaDeEnvio"))

                Agregar_Parrafo_Pdf(doc1, "Remitente: ", "GUATEMALA DIGITAL, S.A", 15)
                Agregar_Parrafo_Pdf(doc1, "", "CALZ.  ROOSEVELT 33-86 Z.7 EDIF ILUMINA OF 602, Tel: 24393259")
                Agregar_Parrafo_Pdf(doc1, "Destinatario: ", destinatario)
                Agregar_Parrafo_Pdf(doc1, "Contacto : ", contacto)
                Agregar_Parrafo_Pdf(doc1, "", nombreDepartamento)
                Agregar_Parrafo_Pdf(doc1, "", nombreMunicipio, 12.0F, "                                       Teléfono: ", telefono)
                Agregar_Parrafo_Pdf(doc1, "Fecha : ", fechaHora)
                Agregar_Parrafo_Pdf(doc1, "Factura : ", codigoFactura, 16.0F)
                If CodigoFormaDeEnvio = 2 Then
                    Agregar_Parrafo_Pdf(doc1, "Tipo de Envío : ", "Express", 17.0F)
                End If
                If CodigoFormaDeEnvio = 3 Then
                    Agregar_Parrafo_Pdf(doc1, "Tipo de Envío : ", "Super Express", 17.0F)
                End If

                SQL.Clear()
                SQL.AppendLine("SELECT")
                SQL.AppendLine(" COUNT(1)")
                SQL.AppendLine("FROM Cobro AS COB")
                SQL.AppendLine("INNER JOIN Factura AS FAC")
                SQL.AppendLine("  ON COB.CodigoFactura = FAC.CodigoFactura")
                SQL.AppendLine("WHERE COB.CodigoFactura = " & codigoFactura)
                SQL.AppendLine("AND COB.CodigoFormaDePago = 1 AND COB.Estado = 1")
                SQL.AppendLine("AND FAC.CodigoEmpresaDeEntrega <> 2")

                Dim ValidarCOD = Cargar.retornarentero(SQL.ToString, MyConString)

                If ValidarCOD > 0 Then
                    SQL.Clear()
                    SQL.AppendLine("SELECT")
                    SQL.AppendLine(" SUM(MontoCuota) AS MontoCuota")
                    SQL.AppendLine("FROM Cobro AS COB")
                    SQL.AppendLine("INNER JOIN Factura AS FAC")
                    SQL.AppendLine("  ON COB.CodigoFactura = FAC.CodigoFactura")
                    SQL.AppendLine("WHERE COB.CodigoFactura = " & codigoFactura)
                    SQL.AppendLine("AND COB.CodigoFormaDePago = 1 AND COB.Estado = 1")
                    SQL.AppendLine("AND FAC.CodigoEmpresaDeEntrega <> 2")
                    Dim CobroCOD = Cargar.retornardecimal(SQL.ToString, MyConString)
                    Agregar_Parrafo_Pdf(doc1, "COD : ", CobroCOD.ToString, 16.0F)
                End If

                'Generacion codigo Barras
                bc.Code = codigoRastreo
                bc.CodeType = iTextSharp.text.pdf.Barcode128.CODE128
                bc.Extended = True
                Dim cb As PdfContentByte = writer.DirectContent
                Dim codigoBarras As iTextSharp.text.Image = bc.CreateImageWithBarcode(cb, BaseColor.BLACK, BaseColor.BLACK)
                codigoBarras.ScalePercent(110.0F)
                codigoBarras.Alignment = Element.ALIGN_LEFT

                Dim p1 As Paragraph = New Paragraph(f1)

                p1.Alignment = Element.ALIGN_LEFT
                doc1.Add(p1)
                doc1.Add(codigoBarras)
                doc1.Close()
            End If

            If System.IO.File.Exists(ruta) Then
                'DESARROLLO
                Dim rutaPDF As String = "/Sistema/Guias/GUIAGENERADA.pdf"
                Dim scriot As String = "openInNewTab2('" & rutaPDF & "')"

                ScriptManager.RegisterStartupScript(Me.Page, Me.GetType(), "SIFEL", scriot, True)
            End If
        Catch ex As Exception
            LblRespuesta.Text = "Ha ocurrido un error al momento de imprimir la guia " & ex.ToString()
        End Try

        validarBtnImprimirGuiaGT()
    End Sub

    Protected Sub validarBtnImprimirGuiaGT()
        Dim exito As Boolean = False
        Consulta = "SELECT TOP 1 ISNULL(CodigoDeRastreo, '0') AS CodigoDeRastreo " &
                 "FROM Factura " &
                 "WHERE codigoFactura = " & txtCodigoFactura.Text.Trim

        Dim codigoDeRastreo = Cargar.retornarcadena(Consulta, MyConString)

        If codigoDeRastreo <> "0" And codigoDeRastreo <> "" Then
            Consulta = "SELECT CodigoEmpresaDeEntrega " &
                        "FROM Factura  where CodigoFactura = " & txtCodigoFactura.Text.Trim

            Dim empresaEntrega As Integer = CInt(Cargar.retornarenterocorto(Consulta, MyConString))
            Consulta = "SELECT CodigoEstadoEntrega " &
               "FROM Venta WHERE CodigoFactura = " & txtCodigoFactura.Text.Trim

            Dim estadoFactura = CInt(Cargar.retornarenterocorto(Consulta, MyConString))

            If empresaEntrega <> 2 And estadoFactura <> 6 Then
                exito = True
            End If
        End If

        btnImprimirGuiaGT.Visible = exito
    End Sub

    Sub Agregar_Parrafo_Pdf(ByRef doc1 As Document, ByVal titulo1 As String, ByVal texto1 As String, ByVal Optional lineheight As Single = 12.0F,
ByVal Optional titulo2 As String = "", ByVal Optional texto2 As String = "",
ByVal Optional titulo3 As String = "", ByVal Optional texto3 As String = "")
        'crear fuente y tamaño de la fuente
        Dim fuente As BaseFont = BaseFont.CreateFont(BaseFont.HELVETICA, BaseFont.WINANSI, False)
        Dim fuente12Normal As Font = New Font(fuente, 9, iTextSharp.text.Font.NORMAL, BaseColor.BLACK)
        Dim fuente11Negrita As Font = New Font(fuente, 8, iTextSharp.text.Font.BOLD, BaseColor.BLACK)


        Dim txtNegrita As Chunk = New Chunk(titulo1, fuente11Negrita)
        Dim txtNormal As Chunk = New Chunk(texto1, fuente12Normal)
        Dim f1 As Phrase = New Phrase()

        f1.Add(txtNegrita) : f1.Add(txtNormal)

        If titulo2 <> "" And texto2 <> "" Then
            Dim txtnegrita1 As Chunk = New Chunk(titulo2, fuente11Negrita)
            Dim txtNormal1 As Chunk = New Chunk(texto2, fuente12Normal)
            f1.Add(txtnegrita1) : f1.Add(txtNormal1)

            If titulo3 <> "" And texto3 <> "" Then
                Dim txtnegrita2 As Chunk = New Chunk(titulo3, fuente11Negrita)
                Dim txtNormal2 As Chunk = New Chunk(texto3, fuente12Normal)
                f1.Add(txtnegrita2) : f1.Add(txtNormal2)
            End If

        End If

        Dim p1 As Paragraph = New Paragraph(f1)
        p1.Leading = lineheight
        p1.Alignment = Element.ALIGN_LEFT

        doc1.Add(p1)
    End Sub

    Sub Obtener_Datos_De_Factura(ByVal Cadena As String, ByRef NIT As String, ByRef NombreFactura As String, ByRef DireccionFactura As String)
        Dim IndiceNit, IndiceDir As Integer

        Consulta = "Select CodigoCliente from cliente where Correo = '" & TxtCorreoCliente.Text & "'"
        LblCodigoCliente.Text = CStr(Cargar.retornarentero(Consulta, MyConString))
        Cadenaglobal = "SELECT COUNT(CodigoCliente) FROM Venta WHERE CodigoCliente = " & LblCodigoCliente.Text & " AND Confirmada = 1"
        lblCantidadDeCompras.Text = CStr(Cargar.retornarentero(Cadenaglobal, MyConString))

        If Cadena = "" Then
            NIT = ""
            NombreFactura = ""
            DireccionFactura = ""
        Else
            IndiceNit = Cadena.IndexOf("NIT:")
            IndiceDir = Cadena.IndexOf("DIR:")

            If IndiceNit = -1 Then

                NIT = ""
                If IndiceDir = -1 Then
                    DireccionFactura = ""
                    NombreFactura = Cadena.Substring(0)
                Else
                    NombreFactura = Cadena.Substring(0, IndiceDir)
                    DireccionFactura = Cadena.Substring(IndiceDir + 4)
                End If
            Else
                If IndiceDir = -1 Then
                    NombreFactura = Cadena.Substring(0, IndiceNit)
                    NIT = Cadena.Substring(IndiceNit + 4)
                Else
                    NombreFactura = Cadena.Substring(0, IndiceNit)
                    NIT = Cadena.Substring(IndiceNit + 4, IndiceDir - IndiceNit - 4)
                    DireccionFactura = Cadena.Substring(IndiceDir + 4)
                End If
            End If
        End If
    End Sub

    Sub Cargar_Encabezado(CodigoFactura As String)
        Dim Factura As String
        Dim NitCliente, NombreCliente, DireccionCliente As String

        If CodigoFactura <> "0" Then
            Consulta = "" & vbLf
            Consulta += " Select " & vbLf
            Consulta += " VEN.Factura," & vbLf
            Consulta += " CLI.Correo," & vbLf
            Consulta += " VEN.Telefonos," & vbLf
            Consulta += " VEN.NombreCliente," & vbLf
            Consulta += " VEN.DireccionDeEntrega," & vbLf
            Consulta += " FAC.CodigoDepartamento," & vbLf
            Consulta += " FAC.CodigoMunicipio," & vbLf
            Consulta += " FAC.CodigoEmpresaDeEntrega," & vbLf
            Consulta += " FAC.CodigoDeRastreo," & vbLf
            Consulta += " ISNULL(FDE.CodigoFormaDeEnvio, 0) AS FormaDeEnvio" & vbLf
            Consulta += " From VENTA As VEN" & vbLf
            Consulta += " INNER Join CLIENTE AS CLI" & vbLf
            Consulta += " On VEN.CodigoCliente = CLI.CodigoCliente" & vbLf
            Consulta += " LEFT JOIN Factura AS FAC" & vbLf
            Consulta += " On VEN.CodigoFactura = FAC.CodigoFactura" & vbLf
            Consulta += " Left Join FormaDeEnvio AS FDE" & vbLf
            Consulta += " On FDE.CodigoFormaDeEnvio = FAC.CodigoFormaDeEnvio" & vbLf
            Consulta += " WHERE VEN.CodigoFactura = " & CodigoFactura

            Using mySqlConnection As New System.Data.SqlClient.SqlConnection(MyConString)
                mySqlConnection.Open()

                Dim mySqlCommand As New System.Data.SqlClient.SqlCommand(Consulta, mySqlConnection)
                Dim myDataReader As Data.SqlClient.SqlDataReader

                myDataReader = mySqlCommand.ExecuteReader()

                Consulta = "Select CodigoCliente from cliente where Correo = '" & TxtCorreoCliente.Text & "'"
                LblCodigoCliente.Text = CStr(Cargar.retornarentero(Consulta, MyConString))
                Cadenaglobal = "SELECT COUNT(CodigoCliente) FROM Venta WHERE CodigoCliente = " & LblCodigoCliente.Text & " AND Confirmada = 1"
                lblCantidadDeCompras.Text = CStr(Cargar.retornarentero(Cadenaglobal, MyConString))

                'Cargar datos a la tabla Detalle   
                Do While (myDataReader.Read())
                    If myDataReader.IsDBNull(0) = False Then
                        Factura = myDataReader.GetString(0)
                        Obtener_Datos_De_Factura(Factura, NitCliente, NombreCliente, DireccionCliente)
                        TxtNombreFactura.Text = NombreCliente
                        Dim ItemNit As New wsGD.ItemNit
                        Dim Cliente As New wsGD.Service

                        Dim NIT = NitCliente.ToString.ToUpper.Replace(" ", "").Replace("/", "").Replace("-", "").Trim
                        TxtNitCliente.Text = Trim(NitCliente)
                        TxtDireccionCliente.Text = Trim(DireccionCliente)

                    Else
                        TxtNombreFactura.Text = ""
                        TxtNitCliente.Text = ""
                        TxtDireccionCliente.Text = ""
                    End If

                    If myDataReader.IsDBNull(1) = False Then
                        TxtCorreoCliente.Text = myDataReader.GetString(1)
                    End If

                    If txtCodigoFactura.Text = "0" Then
                        CargarTelefonos(CodigoFactura)
                    Else
                        CargarTelefonos(CodigoFactura)
                    End If

                    If myDataReader.IsDBNull(3) = False Then
                        TxtNombreCliente.Text = myDataReader.GetString(3)
                        Page.Title = "Factura " & TxtNombreCliente.Text

                    Else
                        TxtNombreCliente.Text = ""
                        Page.Title = "Factura " & TxtNombreCliente.Text

                    End If
                    If myDataReader.IsDBNull(4) = False Then
                        TxtDireccionEntrega.Text = myDataReader.GetString(4)
                    Else
                        TxtDireccionEntrega.Text = ""
                    End If

                    If myDataReader.IsDBNull(5) = False Then
                        DdlDepartamento.SelectedValue = CStr(myDataReader.GetInt16(5))
                    Else
                        Dim departamentoFactura = Cargar.retornarcadena("SELECT CAST(ISNULL(CodigoDepartamento, 0) AS VARCHAR) AS CodigoDepartamento FROM Factura WHERE CodigoFactura = " & txtCodigoFactura.Text, MyConString)
                        DdlDepartamento.SelectedValue = CStr(IIf(departamentoFactura = "", 0, departamentoFactura))
                    End If

                    Consulta = "select 0 as CodigoMunicipio, '' as Nombre union select CodigoMunicipio, Nombre from Municipio where CodigoDepartamento = " & DdlDepartamento.SelectedValue & " order by Nombre "
                    Cargar.CargarDDL("Nombre", "CodigoMunicipio", Consulta, DdlMunicipio, MyConString)

                    If myDataReader.IsDBNull(6) = False Then 'Municipio
                        DdlMunicipio.SelectedValue = CStr(myDataReader.GetInt16(6))
                    End If

                    txtCodigoDeRastreo.Text = ""
                    LblCodigoDeRastreo.Text = ""
                    HlkImprimir_Guia.Visible = False
                    BtnGenerarGuia.Visible = True
                    If verificarCobrosConfirmados() Then
                        BtnGuardarGuia.Visible = True

                    Else
                        BtnGuardarGuia.Visible = False
                    End If
                    BtnEliminarGuia.Visible = False
                    txtCodigoDeRastreo.ReadOnly = False
                    DdlEmpresaDeEntrega.SelectedValue = "0"
                    BtnGuardarGuia.Enabled = False
                    BtnGenerarGuia.Enabled = False
                Loop

                myDataReader.Close()
                mySqlConnection.Close()
                'finaliza carga de datos a la tabla detalle
            End Using

            If CInt(txtCodigoFactura.Text) <> 0 Then
                'Tarea: 794
                Consulta = "select f.SinFactura, f.Observaciones, case when f.Fecha is not null then f.Fecha else f.FechaRegistro end, f.FechaGuia, f.CodigoEstadoFactura, case when CONVERT (date, GETDATE()) = CONVERT (date, f.FechaGuia) then 1 else 0 end  as PermitirEliminarGuia, f.FechaEntrega, dbo.Lista_Valores(12,'" & txtCodigoFactura.Text & "','','','') as GuiasAnuladas, f.CodigoDeRastreo, f.CodigoEmpresaDeEntrega, f.ObservacionesGuia, u.Nombre from factura f LEFT JOIN Usuario u ON f.CodigoUsuarioGuia = u.CodigoUsuario where CodigoFactura = " & txtCodigoFactura.Text

                Using mySqlConnection As New System.Data.SqlClient.SqlConnection(MyConString)
                    mySqlConnection.Open()

                    Dim mySqlCommand As New System.Data.SqlClient.SqlCommand(Consulta, mySqlConnection)
                    Dim myDataReader As Data.SqlClient.SqlDataReader

                    myDataReader = mySqlCommand.ExecuteReader()

                    'Cargar datos a la tabla Detalle    
                    Do While (myDataReader.Read())
                        If myDataReader.IsDBNull(1) = False Then

                            Dim text_temp As String = myDataReader.GetString(1)
                            Dim pattern As New Regex("{PartesCombo([^}]+)}")
                            Dim matches As MatchCollection = pattern.Matches(text_temp)

                            For Each m As Match In matches
                                text_temp = text_temp.Replace(m.Value, String.Empty)
                            Next
                        End If
                        If myDataReader.IsDBNull(2) = False Then
                            TxtFechaFactura.Text = myDataReader.GetDateTime(2).ToString("dd/MM/yyyy HH:mm:ss")
                        Else
                            TxtFechaFactura.Text = ""
                        End If
                        If myDataReader.IsDBNull(3) = False Then
                            TxtFechaGuia.Text = myDataReader.GetDateTime(3).ToString("dd/MM/yyyy HH:mm:ss")
                        Else
                            TxtFechaGuia.Text = ""
                        End If

                        'si la factura ya tiene serie, no debe dejar imprimir guías
                        If myDataReader.IsDBNull(4) = False Then
                            If myDataReader.GetInt32(4) > 0 Then
                                HlkImprimir_Guia.Visible = False
                            End If
                        End If

                        'verifica la fecha de la guía es distinto al día actual, no debe dejar imrimir guías
                        If myDataReader.IsDBNull(5) = False Then
                            If myDataReader.GetInt32(5) = 0 Then
                                HlkImprimir_Guia.Visible = False
                            End If
                        End If

                        'Tarea: 794
                        If myDataReader.IsDBNull(6) = False Then
                            lblFechaEntrega.Text = "Fecha de entrega: " & myDataReader.GetDateTime(6).ToString("dd/MM/yyyy HH:mm:ss")
                        End If

                        LblGuiasAnuladas.Text = ""
                        If myDataReader.IsDBNull(7) = False Then
                            If Len(Trim(myDataReader.GetString(7))) > 0 Then
                                LblGuiasAnuladas.Text = "Guías Eliminadas: " & myDataReader.GetString(7)
                            End If
                        End If

                        If myDataReader.IsDBNull(8) = False Then 'Codigo de ratreo
                            txtCodigoDeRastreo.Text = myDataReader.GetString(8)
                            LblCodigoDeRastreo.Text = myDataReader.GetString(8)
                            If Trim(txtCodigoDeRastreo.Text) <> "" Then
                                Dim empresaDeEntrega As String
                                If myDataReader.IsDBNull(9) = False Then 'Codigo empresa de entrega
                                    empresaDeEntrega = CStr(myDataReader.GetInt16(9))
                                Else
                                    empresaDeEntrega = "0"
                                End If
                                If empresaDeEntrega = "2" Then
                                    HlkImprimir_Guia.Visible = True
                                Else
                                    HlkImprimir_Guia.Visible = False
                                End If

                                Dim vUrl As String = System.Configuration.ConfigurationManager.AppSettings("CargoExpreso").ToString & txtCodigoDeRastreo.Text & "&Login=WSGUATEDIGITAL"
                                HlkImprimir_Guia.NavigateUrl = vUrl
                                BtnGenerarGuia.Visible = False
                                BtnGuardarGuia.Visible = False
                                BtnEliminarGuia.Visible = True
                                txtCodigoDeRastreo.Visible = False
                                txtCodigoDeRastreo.ReadOnly = True
                            Else
                                HlkImprimir_Guia.Visible = False
                                HlkImprimir_Guia.NavigateUrl = ""
                                BtnGenerarGuia.Visible = True
                                If verificarCobrosConfirmados() Then
                                    BtnGuardarGuia.Visible = True
                                Else
                                    BtnGuardarGuia.Visible = False
                                End If
                                BtnEliminarGuia.Visible = False
                                txtCodigoDeRastreo.ReadOnly = False
                            End If
                        Else
                            txtCodigoDeRastreo.Text = ""
                            LblCodigoDeRastreo.Text = ""
                            HlkImprimir_Guia.Visible = False
                            BtnGenerarGuia.Visible = True
                            If verificarCobrosConfirmados() Then
                                BtnGuardarGuia.Visible = True
                            Else
                                BtnGuardarGuia.Visible = False
                            End If
                            BtnEliminarGuia.Visible = False
                            txtCodigoDeRastreo.ReadOnly = False
                        End If

                        If myDataReader.IsDBNull(9) = False Then 'Codigo empresa de entrega
                            DdlEmpresaDeEntrega.SelectedValue = CStr(myDataReader.GetInt16(9))
                        Else
                            DdlEmpresaDeEntrega.SelectedValue = "0"
                            BtnGuardarGuia.Enabled = False
                            BtnGenerarGuia.Enabled = False
                        End If

                        If Not myDataReader.IsDBNull(10) Then
                            txtObservacionesGuia.Text = myDataReader.GetString(10).Trim
                            If LblCodigoDeRastreo.Text.Trim.Length > 0 Then
                                txtObservacionesGuia.ReadOnly = True
                            End If
                            '
                        End If
                        If myDataReader.IsDBNull(11) = False Then 'Nombre de quien generó la guia
                            lblcreadapor.Text = "(" & myDataReader.GetString(11) & ")"
                        End If
                    Loop

                    myDataReader.Close()
                    mySqlConnection.Close()
                    'finaliza carga de datos a la tabla detalle
                End Using
            Else
                TxtFechaFactura.Text = ""
                TxtFechaGuia.Text = ""
            End If
            ' ------------------ FormaEnvio --------------------------
            Dim formaEnvio As Integer = Cargar.retornarentero("SELECT TOP(1) MAX(ISNULL(CodigoFormaDeEnvio, 0)) FROM Factura WHERE CodigoFactura = " & CodigoFactura, MyConString)

            If formaEnvio = 3 Then
                lblFormaDeEnvio.Text = "SuperExpress"
                lblFormaDeEnvio.ForeColor = System.Drawing.Color.Red
                lblFormaDeEnvio.Font.Size = New FontUnit(18)
                lblFormaDeEnvio.Visible = True
            ElseIf formaEnvio = 2 Then
                lblFormaDeEnvio.Text = "Express"
                lblFormaDeEnvio.ForeColor = System.Drawing.Color.Red
                lblFormaDeEnvio.Font.Size = New FontUnit(14)
                lblFormaDeEnvio.Visible = True
            ElseIf formaEnvio = 1 Then
                lblFormaDeEnvio.Text = "Normal"
                lblFormaDeEnvio.ForeColor = System.Drawing.Color.Green
                lblFormaDeEnvio.Font.Size = New FontUnit(12)
                lblFormaDeEnvio.Visible = True
            ElseIf formaEnvio = 0 Then
                lblFormaDeEnvio.Text = "Incluido"
                lblFormaDeEnvio.ForeColor = System.Drawing.Color.Green
                lblFormaDeEnvio.Font.Size = New FontUnit(12)
                lblFormaDeEnvio.Visible = True
            End If
        Else
            TxtNombreCliente.Text = ""
            TxtDireccionCliente.Text = ""
            TxtNitCliente.Text = ""
            TxtCorreoCliente.Text = ""

            'Tarea: 794
            Consulta = "select f.Nombre, f.Direccion, f.Nit, c.Correo, f.Telefonos, f.SinFactura, f.CodigoDeRastreo, f.CodigoEstadoFactura, case when CONVERT (date, GETDATE()) = CONVERT (date, f.FechaGuia) then 1 else 0 end  as PermitirEliminarGuia, FechaEntrega, dbo.Lista_Valores(12,'" & txtCodigoFactura.Text & "','','','') as GuiasAnuladas, f.CodigoEmpresaDeEntrega, f.CodigoDepartamento, f.CodigoMunicipio  from Factura f, Cliente c where f.CodigoCliente = c.CodigoCliente and f.CodigoFactura = " & txtCodigoFactura.Text

            Using mySqlConnection As New System.Data.SqlClient.SqlConnection(MyConString)
                mySqlConnection.Open()
                Dim mySqlCommand As New System.Data.SqlClient.SqlCommand(Consulta, mySqlConnection)
                Dim myDataReader As Data.SqlClient.SqlDataReader
                myDataReader = mySqlCommand.ExecuteReader()

                Do While myDataReader.Read()
                    If myDataReader.IsDBNull(0) = False Then
                        TxtNombreFactura.Text = myDataReader.GetString(0)
                    End If
                    If myDataReader.IsDBNull(1) = False Then
                        TxtDireccionCliente.Text = myDataReader.GetString(1)
                    End If
                    If myDataReader.IsDBNull(2) = False Then

                        TxtNitCliente.Text = myDataReader.GetString(2)
                    End If
                    If myDataReader.IsDBNull(3) = False Then
                        TxtCorreoCliente.Text = myDataReader.GetString(3)
                    End If
                    If myDataReader.IsDBNull(4) = False Then
                        'TxtTelefonos.Text = myDataReader.GetString(4)
                    End If
                    If myDataReader.IsDBNull(5) = False Then
                        'TxtSinFactura.Text = myDataReader.GetString(4)
                    End If

                    If myDataReader.IsDBNull(6) = False Then 'Codigo de ratreo
                        txtCodigoDeRastreo.Text = myDataReader.GetString(6)
                        LblCodigoDeRastreo.Text = myDataReader.GetString(6)
                        txtObservacionesGuia.ReadOnly = True
                        If Trim(txtCodigoDeRastreo.Text) <> "" Then
                            HlkImprimir_Guia.Visible = True

                            Dim vUrl As String = System.Configuration.ConfigurationManager.AppSettings("CargoExpreso").ToString & txtCodigoDeRastreo.Text & "&Login=WSGUATEDIGITAL"
                            HlkImprimir_Guia.NavigateUrl = vUrl
                            BtnGenerarGuia.Visible = False
                            BtnGuardarGuia.Visible = False
                            BtnEliminarGuia.Visible = True
                            txtCodigoDeRastreo.Visible = False
                            txtCodigoDeRastreo.ReadOnly = True
                        Else
                            HlkImprimir_Guia.Visible = False
                            HlkImprimir_Guia.NavigateUrl = ""
                            BtnGenerarGuia.Visible = True
                            If verificarCobrosConfirmados() Then
                                BtnGuardarGuia.Visible = True
                            Else
                                BtnGuardarGuia.Visible = False
                            End If
                            BtnEliminarGuia.Visible = False
                            txtCodigoDeRastreo.ReadOnly = False

                        End If
                    Else
                        txtCodigoDeRastreo.Text = ""
                        LblCodigoDeRastreo.Text = ""
                        HlkImprimir_Guia.Visible = False
                        BtnGenerarGuia.Visible = True
                        If verificarCobrosConfirmados() Then
                            BtnGuardarGuia.Visible = True
                        Else
                            BtnGuardarGuia.Visible = False
                        End If
                        BtnEliminarGuia.Visible = False
                        txtCodigoDeRastreo.ReadOnly = False
                    End If

                    'si la factura ya tiene serie, no deja ver el enlace de imprimir guías
                    If myDataReader.GetInt32(7) > 0 Then
                        HlkImprimir_Guia.Visible = False
                    End If

                    'si fechaguia es distinto al día actual, no deja ver el enlace de imprimir guías
                    If myDataReader.IsDBNull(8) = False Then
                        If myDataReader.GetInt32(8) = 0 Then
                            HlkImprimir_Guia.Visible = False
                        End If
                    End If

                    'Tarea: 794
                    If myDataReader.IsDBNull(9) = False Then
                        lblFechaEntrega.Text = "Fecha de entrega: " & myDataReader.GetDateTime(9).ToString("dd/MM/yyyy HH:mm:ss")
                    End If

                    LblGuiasAnuladas.Text = ""
                    If myDataReader.IsDBNull(10) = False Then
                        If Len(Trim(myDataReader.GetString(10))) > 0 Then
                            LblGuiasAnuladas.Text = "Guías Eliminadas: " & myDataReader.GetString(10)
                        End If

                    End If

                    If myDataReader.IsDBNull(11) = False Then 'Codigo empresa de entrega
                        DdlEmpresaDeEntrega.SelectedValue = CStr(myDataReader.GetInt16(11))
                    Else
                        DdlEmpresaDeEntrega.SelectedValue = "2"
                    End If

                    If myDataReader.IsDBNull(12) = False Then 'Codigo Departamento
                        DdlDepartamento.SelectedValue = CStr(myDataReader.GetInt16(12))
                    Else
                        DdlDepartamento.SelectedValue = "0"
                    End If

                    If myDataReader.IsDBNull(13) = False Then 'Codigo Municipio
                        Consulta = "select 0 as CodigoMunicipio, '' as Nombre union select CodigoMunicipio, Nombre from Municipio where CodigoDepartamento = " & DdlDepartamento.SelectedValue & " order by Nombre "
                        Cargar.CargarDDL("Nombre", "CodigoMunicipio", Consulta, DdlMunicipio, MyConString)
                        DdlMunicipio.SelectedValue = CStr(myDataReader.GetInt16(13))
                    Else
                        DdlMunicipio.SelectedValue = "0"
                    End If
                Loop
                myDataReader.Close()
                mySqlConnection.Close()
            End Using
        End If
    End Sub

    Sub CargarTelefonos(ByVal CodigoFactura As String)
        Dim vTelefonos As String = ""
        Dim vTelefono As String = " "
        Consulta = "SELECT isnull(CodigoFactura,0) from Venta where CodigoFactura = " & CodigoFactura
        Dim vFac As String = Cargar.retornarentero(Consulta, MyConString).ToString()
        If Not vFac = "0" Then
            Consulta = "SELECT Telefonos from Venta where CodigoFactura = " & vFac
            Dim dt As New DataTable
            Cargar.ejecuta_query_dt(Consulta, dt, MyConString)
            If dt.Rows.Count > 0 Then
                For i As Integer = 0 To dt.Rows.Count - 1
                    Dim dr As DataRow = dt.Rows(i)
                    If (i < dt.Rows.Count - 1) Then
                        Dim vTelReemplazo As String
                        vTelReemplazo = dr(0).ToString()
                        If vTelReemplazo.Contains("/") Then
                            vTelReemplazo = vTelReemplazo.Replace("/", " || ")
                        ElseIf vTelReemplazo.Contains("\") Then
                            vTelReemplazo = vTelReemplazo.Replace("\", " || ")
                        End If
                        vTelefonos = vTelefonos & vTelReemplazo & "||"
                    Else
                        vTelefonos = vTelefonos & dr(0).ToString()
                    End If
                Next i
            End If
        Else
            Consulta = "SELECT Telefonos from Venta where CodigoVenta = " & CodigoFactura
            vTelefonos = Cargar.retornarcadena(Consulta, MyConString)
            If vTelefonos.Contains("/") Then
                vTelefonos = vTelefonos.Replace("/", " || ")
            ElseIf vTelefonos.Contains("\") Then
                vTelefonos = vTelefonos.Replace("\", " || ")
            End If
        End If
        Dim vTels() As String
        vTels = vTelefonos.Split(CChar("||"))
        If vTels.Length = 1 Then
            vTelefono = vTels(0)
        Else
            For i2 As Integer = 0 To vTels.Length - 1
                If Not vTelefono.Contains(" " + vTels(i2).Trim() + " ||") And Not vTelefono.Contains(" " + vTels(i2).Trim() + " ") Then
                    vTelefono = vTelefono & vTels(i2) & " || "
                End If
            Next i2
        End If
        vTelefono = vTelefono.Trim()
        If vTelefono.Trim.Length > 2 Then
            If vTelefono.Trim.Substring(vTelefono.Length - 2, 2) = "||" Then
                vTelefono = vTelefono.Trim.Substring(0, vTelefono.Length - 2)
            End If
        End If
        If vTelefono.Contains("  ") Then
            TxtTelefonos.Text = vTelefono.Replace("  ", " ").Trim()
        Else
            TxtTelefonos.Text = vTelefono.Trim()
        End If
    End Sub

    Sub Obtener_Cobros_Factura(ByRef TotalCobros As Decimal, ByRef TotalCobrosSinComisiones As Decimal, ByRef TotalPendiente As Decimal, ByVal CodigoCobro As String)
        Dim Parametro As String
        Dim NumVentas As Integer

        Parametro = ""
        If CodigoCobro <> "" Then
            Parametro = " And Codigocobro <> " & CodigoCobro & " "
        End If

        Consulta = "select COUNT(1) from Factura f, Venta v, Producto p  " &
    "where f.CodigoFactura = v.CodigoFactura And v.CodigoProducto = p.CodigoProducto " &
    "and p.ComisionDeTarjeta = 'false' and f.CodigoFactura = " & txtCodigoFactura.Text

        If Cargar.retornarentero(Consulta, MyConString) = 0 Then
            Consulta = "DECLARE @CUOTA INT "
            Consulta += "SET @CUOTA = (SELECT MAX(Cuotas) FROM Cobro WHERE ReembolsoTC IS NULL AND Estado = 1 AND CodigoFormaDePago = 3 AND CodigoFactura = " & txtCodigoFactura.Text & "); "
            Consulta += "select isnull(sum(case when CodigoFormaDePago <> 3 AND ReembolsoTC IS NULL then MontoCuota WHEN ReembolsoTC = 1 THEN dbo.Cobros_Montos_Sin_Cargo_Tarjeta_Credito(2,MontoCuota,@CUOTA) else  dbo.Cobros_Montos_Sin_Cargo(1, CodigoCobro, MontoCuota, Cuotas) end),0) from Cobro where CodigoFactura = " & txtCodigoFactura.Text & " and Estado = 'True' " & Parametro
            TotalCobrosSinComisiones = Cargar.retornardecimal(Consulta, MyConString)
        Else
            Consulta = "select isnull(sum(case when CodigoFormaDePago <> 3 then MontoCuota else  MontoCuota * Cuotas end),0) from Cobro where CodigoFactura = " & txtCodigoFactura.Text & " and Estado = 'True'" & Parametro
            TotalCobrosSinComisiones = Cargar.retornardecimal(Consulta, MyConString)
        End If
        'End If
        Consulta = "select isnull(sum(case when CodigoFormaDePago <> 3 then MontoCuota else MontoCuota * Cuotas end),0) from Cobro where CodigoFactura = " & txtCodigoFactura.Text & " and Estado = 'True'" & Parametro
        TotalCobros = Cargar.retornardecimal(Consulta, MyConString)

        Consulta = "Select count(1) from Venta Where CodigoFactura = " & txtCodigoFactura.Text
        NumVentas = Cargar.retornarentero(Consulta, MyConString)
    End Sub

    Sub Guardar_Datos_Archivo_Texto(ByVal Cadena As String)
        Dim key As String = "Logs/CargoExpresoGuias" & Date.Now.Day.ToString & Date.Now.Month.ToString & ".txt"
        Dim cliente As New wsGD.Service
        Dim bucket As New wsGD.itemBucket
        Dim contenido As String = ""
        Dim bytes As Byte()

        Try
            contenido = cliente.ObtenerContenidoObjetoBucket(key, "gd-archivospaginas")
            If contenido = "" Then
                contenido = Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            Else
                contenido &= Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            End If
        Catch e As Exception
            If contenido = "" Then
                contenido = Date.Now.ToString & vbNewLine & Cadena & vbNewLine & " " & vbNewLine
            End If
        End Try

        bytes = System.Text.Encoding.UTF8.GetBytes(contenido)
        Dim base64 = Convert.ToBase64String(bytes)

        bucket = cliente.uploadfileStream(key, base64, "gd-archivospaginas")
        If Not bucket.Resultado.ToString = "True" Then
            LblRespuesta.Text = "ERROR AL SUBIR ARCHIVO"
        End If
    End Sub

    ''' <summary>
    ''' Procedimiento para enviar alerta a slack
    ''' </summary>
    ''' <param name="Canal">El canal a donde se manda la alerta</param>
    ''' <param name="TituloAlerta">El titulo que tiene la alerta</param>
    ''' <param name="Mensaje">El mensaje que se mandara a slack</param>
    ''' <param name="Subject">Subtitulo del mensaje de slack</param>
    ''' <param name="Procedimiento">Es el nombre de la alerta</param>
    Sub EnviarAlertaSlack(ByVal Canal As String, ByVal TituloAlerta As String, ByVal Mensaje As String, ByVal Subject As String, ByVal Procedimiento As String)
        Dim objetoSlack As New wsGD.ObjectSlack
        Dim textoSlack(0) As wsGD.TextosSlack
        Dim jSonSlack As String = ""
        Dim wsGD As New wsGD.Service

        If Canal.Trim.Length > 0 Then
            textoSlack(0) = New wsGD.TextosSlack

            textoSlack(0).Descripcion = Mensaje
            textoSlack(0).Titulo = ""
            textoSlack(0).tShort = True

            objetoSlack.Descripciones = textoSlack
            objetoSlack.Tipo = TituloAlerta
            objetoSlack.Titulo = Subject
            objetoSlack.Proceso = Procedimiento
            objetoSlack.Servidor = My.Computer.Name

            jSonSlack = wsGD.generarJSonSlack(objetoSlack)
            wsGD.Enviar_Resultados_Slack(Canal, jSonSlack)
        End If
    End Sub

    ''' <summary>
    ''' Procedimiento para enviar alerta de envio de express y super express al canal express--super-express
    ''' </summary>
    ''' <param name="Factura">Codigo de la factura</param>
    Sub AlertaSlackEnvioXpress(ByRef Factura As String)
        Dim nombreAlerta As String = ""
        Dim FormaEnvio As String = ""
        Dim mensaje As New StringBuilder
        Dim webhookAlerta As String = ""
        Dim activaAlerta As Boolean = False
        Consulta = "SELECT A.Nombre,W.Url,A.Activo FROM Alerta A INNER JOIN Webhook W ON W.CodigoWebhook = A.CodigoWebhook WHERE CodigoAlerta = 26"
        Dim dt As New DataTable

        Cargar.ejecuta_query_dt(Consulta, dt, MyConString)
        If dt.Rows.Count > 0 Then
            For Each dr As DataRow In dt.Rows
                If dr(0).ToString.Trim.Length > 0 Then
                    nombreAlerta = dr(0).ToString.Trim
                End If
                If dr(1).ToString.Trim.Length > 0 Then
                    webhookAlerta = dr(1).ToString.Trim
                End If
                If dr(2).ToString.Trim.Length > 0 Then
                    activaAlerta = CBool(dr(2).ToString.Trim)
                End If
            Next
        End If
        Dim dt2 As New DataTable

        Consulta = "" & vbLf
        Consulta = "SELECT " & vbLf
        Consulta += "FDE.Nombre, " & vbLf
        Consulta += "v.CodigoProducto, " & vbLf
        Consulta += "v.CodigoVenta " & vbLf
        Consulta += "From Venta v " & vbLf
        Consulta += "Left Join Factura F " & vbLf
        Consulta += "On V.CodigoFactura = F.CodigoFactura " & vbLf
        Consulta += "INNER Join FormaDeEnvio FDE " & vbLf
        Consulta += "  On F.CodigoFormaDeEnvio = FDE.CodigoFormaDeEnvio " & vbLf
        Consulta += "WHERE f.CodigoFormaDeEnvio In (2, 3) " & vbLf
        Consulta += "And v.CodigoFactura Is Not NULL " & vbLf
        Consulta += "And v.CodigoFactura Is Not NULL " & vbLf
        Consulta += "And F.CodigoFactura = " & Factura

        Cargar.ejecuta_query_dt(Consulta, dt2, MyConString)

        If dt2.Rows.Count > 0 Then
            Dim Codes As New StringBuilder
            Dim Orders As New StringBuilder

            For Each dr As DataRow In dt2.Rows
                Codes.Append(dr(1).ToString.Trim & ", ")
                Orders.Append(dr(2).ToString.Trim & ", ")
                FormaEnvio = dr(0).ToString.Trim

                mensaje.Clear()
                mensaje.Append("\nSe envió paquete " + dr(0).ToString.Trim & vbLf)
                mensaje.Append("\nCódigos de productos: " + Codes.ToString & vbLf)
                mensaje.Append("\nCódigos de órdenes: " + Orders.ToString.Trim & vbLf)
                mensaje.Append("\nCodigo de factura: " + Factura)
                mensaje.Append("\n\nUsuario verificación: " + Session("NombreUsuario").ToString & vbLf)
            Next

            If activaAlerta Then
                EnviarAlertaSlack(webhookAlerta, "Envio De Paquete " & FormaEnvio, mensaje.ToString, "Favor de asignar mensajero", nombreAlerta)
            End If
        End If
    End Sub

    Public Sub ActualizarEmpresaEntrega(ByRef cargar As cargar, ByRef MyConString As String)
        If Not DdlMunicipio.SelectedValue = "" AndAlso Not IsNothing(DdlMunicipio.SelectedValue) AndAlso DdlEmpresaDeEntrega.SelectedValue = "0" Then
            Dim Sql As New StringBuilder
            Try
                Sql.Clear()
                Sql.AppendLine("select 0 as CodigoEmpresaDeEntrega, '' as Nombre UNION select EE.CodigoEmpresaDeEntrega, Nombre from EmpresaDeEntrega EE ")
                Sql.AppendLine("INNER JOIN MunicipioEmpresaDeEntrega MEE ON MEE.CodigoEmpresaDeEntrega = EE.CodigoEmpresaDeEntrega ")
                Sql.AppendLine("WHERE EE.Activo = 1 AND MEE.Activo = 1 AND MEE.CodigoMunicipio = " & DdlMunicipio.SelectedValue & " ORDER BY Nombre")
                cargar.CargarDDL("Nombre", "CodigoEmpresaDeEntrega", Sql.ToString, DdlEmpresaDeEntrega, MyConString)
            Catch ex As Exception
                cargar.CargarDDL("Nombre", "CodigoEmpresaDeEntrega", "select 0 as CodigoEmpresaDeEntrega, '' as Nombre UNION select CodigoEmpresaDeEntrega, Nombre from EmpresaDeEntrega order by Nombre", DdlEmpresaDeEntrega, MyConString)
            End Try
        End If
    End Sub
#End Region

#Region "Forms actions"
    Protected Sub grvProductos_RowDataBound(sender As Object, e As GridViewRowEventArgs)
        If e.Row.RowIndex = -1 Then
            e.Row.BackColor = Drawing.Color.ForestGreen
            Return
        End If

        Dim codigoproducto As String = e.Row.Cells(0).Text.Trim()
        Dim nombreproducto As String = e.Row.Cells(1).Text.Trim()
    End Sub

    Protected Sub GdUbicacion_RowDataBound(sender As Object, e As GridViewRowEventArgs)
        If e.Row.RowIndex = -1 Then
            e.Row.BackColor = Drawing.Color.ForestGreen
            Return
        End If

        Dim upc_completo As String = e.Row.Cells(0).Text.Trim()
        Dim desc As String = Regex.Replace(e.Row.Cells(2).Text, "<[^>]*>", "")
        Dim a() As String = desc.Trim.Split(New Char() {" "c})
        Dim cadena As String = ""
        Dim x As Integer

        For x = 0 To UBound(a) - 1
            cadena &= a(x).ToString() + " "
        Next

        cadena = cadena & " "
        e.Row.Cells(2).Text = cadena

        Dim size_upc As Integer = upc_completo.Length

        e.Row.BackColor = Drawing.Color.LightGray

        Dim verificado As Boolean = CType(e.Row.Cells(5).Controls(0), CheckBox).Checked

        If verificado Then
            Dim textbox As TextBox = CType(e.Row.FindControl("TxtVerificaProducto"), TextBox)
            textbox.Text = upc_completo
            textbox.Enabled = False
        End If

        '---------- Escaneos ------------------
        Dim list As LinkedList(Of String)

        If Session("Scanners") Is Nothing Then
            list = New LinkedList(Of String)
        Else
            list = CType(Session("Scanners"), LinkedList(Of String))
        End If

        Dim foundValue As String = getValue(list, e.Row.Cells(8).Text, 0, 1) ' e.Row.Cells(12).Text --> CodigoVenta, en el idx 0 se encuentra la cantidad escaneada

        If String.IsNullOrEmpty(foundValue) Then
            list.AddLast("0;" & e.Row.Cells(6).Text.Trim()) ' e.Row.Cells(8).Text --> CodigoVenta 
            foundValue = "0"
            Session("Scanners") = list
        End If
        If verificado Then
            e.Row.Cells(8).Text = e.Row.Cells(8).Text & "/" & e.Row.Cells(8).Text
        Else
            e.Row.Cells(8).Text = foundValue & "/" & e.Row.Cells(8).Text
        End If
    End Sub

    Protected Sub DdlEmpresaDeEntrega_SelectedIndexChanged(sender As Object, e As EventArgs)
        If DdlEmpresaDeEntrega.SelectedValue.Trim = "0" Then
            BtnGenerarGuia.Enabled = False
            BtnGuardarGuia.Enabled = False
            Exit Sub
        End If
        Consulta = "select isNull(GenerarGuiaGd,0) from EmpresaDeEntrega WHERE CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue
        Dim GeneraGuiaGD As Boolean = Cargar.retornarboolean(Consulta, MyConString)
        If DdlEmpresaDeEntrega.SelectedValue = "2" Or GeneraGuiaGD = True Then
            If verificarCobrosConfirmados() Then
                BtnGenerarGuia.Enabled = True
                BtnGuardarGuia.Enabled = True
            Else
                BtnGenerarGuia.Enabled = False
                BtnGuardarGuia.Enabled = True
            End If
        Else
            BtnGenerarGuia.Enabled = False
            BtnGuardarGuia.Enabled = True
        End If
    End Sub

    Protected Sub chkNoGenerarGuia_CheckedChanged(sender As Object, e As EventArgs)
        If txtCodigoFactura.Text.Trim <> "" And txtCodigoFactura.Text.Trim <> "0" Then
            If chkNoGenerarGuia.Checked Then
                Consulta = "update factura set NoGenerarGuia = 1 where codigofactura = " & txtCodigoFactura.Text.Trim
            Else
                Consulta = "update factura set NoGenerarGuia = 0 where codigofactura = " & txtCodigoFactura.Text.Trim
            End If
            Cargar.insertarmodificareliminar(Consulta, MyConString)
        End If
    End Sub

    Protected Sub DdlMunicipio_SelectedIndexChanged(sender As Object, e As EventArgs)
        LblRespuesta.Text = ""
    End Sub
#Region "Buttons"
    Protected Sub btnAceptar_Click(sender As Object, e As EventArgs)
        Dim consulta As String = Llenar_DataProducto2()
        Dim dt As New DataTable
        lblNombreEstadoGuia.Text = ""
        LblCodigoDeRastreo.Text = ""
        lblcreadapor.Text = ""
        Cargar.ejecuta_query_dt(consulta, dt, MyConString)
        GdUbicacion.DataSource = dt
        GdUbicacion.DataBind()
        Cargar_Encabezado(txtCodigoFactura.Text.Trim)
        MostrarGenerarGuia()
    End Sub

    Protected Sub BtnGenerarGuia_Click(sender As Object, e As EventArgs)
        Dim Consulta As String
        If txtObservacionesGuia.Text.Trim.Length > 110 Then
            LblRespuesta.Text = "Las observaciones de la guía deben ser menores a 182 caracteres."
            Exit Sub
        End If
        If chkNoGenerarGuia.Checked Then
            LblRespuesta.Text = "No se puede generar guía porque está factura está como [No generar guía]"
            Exit Sub
        End If
        Consulta = "select isNull(GenerarGuiaGd,0) from EmpresaDeEntrega WHERE CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue
        If DdlEmpresaDeEntrega.SelectedValue <> "2" And Cargar.retornarboolean(Consulta, MyConString) = False Then
            LblRespuesta.Text = "Debe seleccionar empresa de entrega valida."
            Exit Sub
        End If

        Dim Poblado As String
        Dim NumeroDeguia, UrlConsulta, MensajeError As String
        Dim COD As Decimal
        Dim Fecha, IdManifiesto As String
        Dim Correlativo As Integer

        If Validar_Guia(True) = True Then
            If DdlEmpresaDeEntrega.SelectedValue = "2" Then
                Consulta = "select isnull(sum(c.MontoCuota),0) from Cobro c where c.CodigoFactura = " & txtCodigoFactura.Text & " and c.CodigoFormaDePago = 1 and c.MontoCuota >= 0 and c.Estado = 1 and C.FechaConfirmacion is null "
                COD = Cargar.retornardecimal(Consulta, MyConString)

                NumeroDeguia = "" : UrlConsulta = "" : MensajeError = ""

                Fecha = Date.Now.ToString("yyyy-MM-dd") + " 00:00:00"

                Consulta = "select isnull(MAX(NumeroManifiesto),0) + 1 from Factura where FechaGuia > '" & Fecha & "'"
                Correlativo = Cargar.retornarentero(Consulta, MyConString)

                IdManifiesto = Date.Now.ToString("yyyyMMdd") + CStr(Correlativo)
                Consulta = "select isnull(CodigoCabeceraCargo,'') from Municipio where CodigoMunicipio = " & DdlMunicipio.SelectedValue
                Poblado = Cargar.retornarcadena(Consulta, MyConString)

                If Generar_Guia(TxtNombreCliente.Text, TxtDireccionEntrega.Text, TxtTelefonos.Text, TxtTelefonos2.Text, TxtNombreCliente.Text, TxtNitCliente.Text, Poblado, COD, NumeroDeguia, UrlConsulta, MensajeError, IdManifiesto, Correlativo, txtObservacionesGuia.Text.Trim) = True Then
                    txtCodigoDeRastreo.Text = NumeroDeguia
                    HlkImprimir_Guia.Visible = True
                    BtnGenerarGuia.Visible = False
                    BtnGuardarGuia.Visible = False
                    BtnEliminarGuia.Visible = True
                    txtCodigoDeRastreo.ReadOnly = True
                    HlkImprimir_Guia.NavigateUrl = UrlConsulta

                    Try
                        Guardar_Datos_Archivo_Texto_Correo_Guias_Cliente("Se generó la guía " & NumeroDeguia & " en la factura " & txtCodigoFactura.Text)
                    Catch ex As Exception

                    End Try

                    Enviar_Numero_De_Guia()
                    AlertaSlackEnvioXpress(txtCodigoFactura.Text)
                Else
                    LblRespuesta.Text = MensajeError
                End If
            Else
                Dim Cliente As New wsGD.Service
                Dim Guia As String = Cliente.GenerarGuiaGD(txtCodigoFactura.Text, DdlEmpresaDeEntrega.SelectedValue, CInt(Session("CodigoUsuario")), txtObservacionesGuia.Text.Replace(vbCrLf, " "))
                imprimirGuia()
                If Guia.Contains("Error") Then
                    LblRespuesta.Text = Guia
                Else
                    Dim fe As DateTime
                    fe = Date.Now
                    TxtFechaGuia.Text = fe.ToString("dd/MM/yyyy HH:mm:ss")
                    LblCodigoDeRastreo.Text = CStr(Guia)
                    txtCodigoDeRastreo.Text = CStr(Guia)
                    HlkImprimir_Guia.Visible = False
                    BtnGenerarGuia.Visible = False
                    BtnGuardarGuia.Visible = False
                    BtnEliminarGuia.Visible = True
                    txtCodigoDeRastreo.ReadOnly = True
                    txtCodigoDeRastreo.Visible = False
                    HlkImprimir_Guia.NavigateUrl = ""

                    Dim ConsultaEnviaCorreo As String = "SELECT EnviarCorreoGuia FROM EmpresaDeEntrega Where CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue 'Se consulta si se debe o no enviar la guia 
                    If Cargar.retornarboolean(ConsultaEnviaCorreo, MyConString) = True Then
                        Enviar_Numero_De_Guia() 'Metodo para enviar la guia por correo 
                    End If

                    LblRespuesta.Text = "Se guardó la guía " & txtCodigoDeRastreo.Text & " en la factura"
                    Consulta = "SELECT eef.Nombre FROM Factura f INNER JOIN EstadoEntregaFactura eef ON f.CodigoEstadoEntregaFactura = eef.CodigoEstadoEntregaFactura WHERE f.CodigoFactura = " & txtCodigoFactura.Text
                    lblNombreEstadoGuia.Text = Cargar.retornarcadena(Consulta, MyConString)
                    Consulta = "SELECT u.Nombre FROM Factura f LEFT JOIN Usuario u ON f.CodigoUsuarioGuia = u.CodigoUsuario WHERE f.CodigoFactura = " & txtCodigoFactura.Text
                    lblcreadapor.Text = "(" & Cargar.retornarcadena(Consulta, MyConString).ToString & ")"
                    AlertaSlackEnvioXpress(txtCodigoFactura.Text)
                End If
            End If
        End If 'Validar_Guia
    End Sub

    Protected Sub btnImprimirGuiaGT_Click(sender As Object, e As EventArgs)
        imprimirGuia()
    End Sub

    Protected Sub BtnGuardarGuia_Click(sender As Object, e As EventArgs)
        Dim dtEmpresa As New DataTable
        Dim COD As Decimal
        Dim CadGuia, CadCOD As String
        Dim ListaConsultas, EstadoEntrega, FechaGuia, Resultado As String
        Dim dtFacturaAnulada As New DataTable

        If txtCodigoDeRastreo.Text.Trim = "" Then
            LblRespuesta.Text = "Error, el campo de guía esta vacío"
            Exit Sub
        End If
        Consulta = "Select Prefijo, Nombre, CodigoEmpresaDeEntrega from EmpresaDeEntrega where Prefijo is not null"
        Cargar.ejecuta_query_dt(Consulta, dtEmpresa, MyConString)

        Dim NombreEmpresaGuia As String = ""
        Dim CodigoEmpresaGuia As String = ""
        Dim Encontro As Boolean = False
        If verificar_guia_duplicada(txtCodigoDeRastreo.Text) Then
            Dim consultaguiaasociadaa = "SELECT TOP 1 CodigoFactura FROM Factura WHERE CodigoDeRastreo = '" & txtCodigoDeRastreo.Text & "'"
            Dim resultaguiaasociadaa = Cargar.retornarentero(consultaguiaasociadaa, MyConString)
            LblRespuesta.Text = "La guia " & txtCodigoDeRastreo.Text & " ya se encuentra asociada a la orden " & resultaguiaasociadaa
        Else
            If dtEmpresa.Rows.Count > 0 Then
                For Each dr As DataRow In dtEmpresa.Rows
                    Dim Generacion As String = txtCodigoDeRastreo.Text.Substring(txtCodigoDeRastreo.Text.Trim.Length - 2, 2)
                    If InStr(1, txtCodigoDeRastreo.Text, dr(0).ToString.Trim) = 1 Or Generacion = dr(0).ToString.Trim Then
                        Encontro = True
                        NombreEmpresaGuia = dr(1).ToString.Trim
                        CodigoEmpresaGuia = dr(2).ToString.Trim
                    End If
                Next
            End If
            If Encontro Then
                If Not CodigoEmpresaGuia = DdlEmpresaDeEntrega.SelectedValue.Trim Then
                    LblRespuesta.Text = "Error, el prefijo corresponde a la empresa de entrega " & NombreEmpresaGuia
                    Exit Sub
                End If
            End If

            txtCodigoDeRastreo.Text = Trim(txtCodigoDeRastreo.Text)
            If txtCodigoDeRastreo.Text <> "" Then
                If Validar_Guia(False) Then
                    'retorna el valor que se deberá pagar en efectivo (total de cobros en efectivo
                    If DdlEmpresaDeEntrega.SelectedValue = "2" Then
                        Consulta = "select isnull(sum(c.MontoCuota),0) from Cobro c where c.CodigoFactura = " & txtCodigoFactura.Text & "  and c.CodigoFormaDePago = 1 and c.MontoCuota >= 0 and c.Estado = 1 "
                        COD = Cargar.retornardecimal(Consulta, MyConString)
                    End If
                    Dim fecha As DateTime

                    fecha = Date.Now
                    Dim Iniciales As String = ""
                    Iniciales = txtCodigoDeRastreo.Text.Trim.Substring(0, 2)

                    'verifica si la guía guardada ya existe en alguna factura anulada y se verifica si la factura anulada está en estado de entregada
                    'de ser así, entonces coloca estado de entregada en la venta de la factura, dado que la factura anulada estaba entregada
                    'si no estaba entregada, entonces deja el valor de En Tránsito en la venta de la factura.
                    EstadoEntrega = ", CodigoEstadoEntrega = 5"
                    FechaGuia = "Getdate() "

                    Consulta = "select CodigoEmpresaDeEntrega, CodigoDeRastreo, CodigoEstadoEntregaFactura, convert(nvarchar, FechaGuia, 121) as FechaGuia " &
                  "from factura where CodigoFactura = (select CodigoFacturaAnulada from Factura Where CodigoFactura = " & txtCodigoFactura.Text & ")"

                    Cargar.ejecuta_query_dt(Consulta, dtFacturaAnulada, MyConString)
                    If dtFacturaAnulada.Rows.Count > 0 Then
                        For Each drFacAnulada As DataRow In dtFacturaAnulada.Rows
                            If drFacAnulada("CodigoEmpresaDeEntrega").ToString = DdlEmpresaDeEntrega.SelectedValue And drFacAnulada("CodigoDeRastreo").ToString = txtCodigoDeRastreo.Text.Trim And drFacAnulada("CodigoEstadoEntregaFactura").ToString = "3" Then
                                EstadoEntrega = " CodigoEstadoEntrega = 6 "
                                FechaGuia = "'" & drFacAnulada("FechaGuia").ToString & "' "
                            End If
                        Next
                    End If

                    ListaConsultas = "BEGIN TRANSACTION  BEGIN Try "
                    ListaConsultas += "Update Factura Set CodigoEstadoEntregaFactura = Case When CodigoEstadoEntregaFactura Is null Then 1 Else CodigoEstadoEntregaFactura End, CodigoEmpresaDeEntrega = " & IIf(Iniciales = "GT", "4", DdlEmpresaDeEntrega.SelectedValue.Trim).ToString.Trim & ", CodigoDeRastreo = '" & txtCodigoDeRastreo.Text & "', FechaGuia = " & FechaGuia & CadCOD & ", GuiaGenerada = 0, CodigoUsuarioGuia = " & CInt(Session("CodigoUsuario")) & " Where CodigoFactura = " & txtCodigoFactura.Text.Trim & "; " & vbCrLf
                    ListaConsultas += "update Cobro set CodigoDeRastreo = '" & txtCodigoDeRastreo.Text & "' where CodigoCobro in ( " &
      "select c.CodigoCobro from Cobro c where c.CodigoFactura = " & txtCodigoFactura.Text & "  and c.Estado = 1 " &
      "); " & vbCrLf
                    ListaConsultas += "update Venta set " & EstadoEntrega & CadGuia & " where CodigoEstadoDeVenta <> 2 and CodigoFactura = " & txtCodigoFactura.Text & "; " & vbCrLf
                    ListaConsultas += "Select 'Exito'; "
                    ListaConsultas += "COMMIT TRANSACTION "
                    ListaConsultas += "END TRY "
                    ListaConsultas += "BEGIN CATCH "
                    ListaConsultas += "ROLLBACK TRANSACTION "
                    ListaConsultas += "Select 'Error: ' + ERROR_MESSAGE(); "
                    ListaConsultas += "END CATCH "

                    Resultado = Cargar.retornarcadena(ListaConsultas, MyConString)
                    If Resultado = "Exito" Then
                        LblCodigoDeRastreo.Text = CStr(txtCodigoDeRastreo.Text)

                        HlkImprimir_Guia.Visible = True
                        BtnGenerarGuia.Visible = False
                        BtnGuardarGuia.Visible = False
                        BtnEliminarGuia.Visible = True
                        txtCodigoDeRastreo.ReadOnly = True
                        HlkImprimir_Guia.NavigateUrl = ""

                        Dim ConsultaEnviaCorreo As String = "SELECT EnviarCorreoGuia FROM EmpresaDeEntrega Where CodigoEmpresaDeEntrega = " & DdlEmpresaDeEntrega.SelectedValue 'Se consulta si se debe o no enviar la guia 
                        If Cargar.retornarboolean(ConsultaEnviaCorreo, MyConString) = True Then
                            Enviar_Numero_De_Guia() 'Metodo para enviar la guia por correo 
                        End If

                        LblRespuesta.Text = "Se guardó la guía " & txtCodigoDeRastreo.Text & " en la factura"
                        Consulta = "SELECT eef.Nombre FROM Factura f INNER JOIN EstadoEntregaFactura eef ON f.CodigoEstadoEntregaFactura = eef.CodigoEstadoEntregaFactura WHERE f.CodigoFactura = " & txtCodigoFactura.Text
                        lblNombreEstadoGuia.Text = Cargar.retornarcadena(Consulta, MyConString)
                        validarBtnImprimirGuiaGT()
                        imprimirGuia()
                    Else
                        LblRespuesta.Text = "Error al guardar la guía: " & Resultado
                    End If
                End If

            Else
                LblRespuesta.Text = "Debe de ingresar número de guía"
            End If
        End If
    End Sub

    Protected Sub BtnEliminarGuia_Click(sender As Object, e As EventArgs)
        Dim Consulta As New StringBuilder
        Dim MensajeError As String
        Dim GuiaGenerada As Boolean
        Dim Exito As Boolean
        Dim EstadoAnterior As String = ""
        Dim CodigoEstadoEntregaFactura, CodigoEmpresaDeEntrega As Integer
        Dim Conn As SqlConnection
        Dim myTrans As SqlTransaction
        Dim MyConString As String
        Dim cargar As New cargar
        MyConString = Session("SmyConstring").ToString
        Conn = New SqlConnection(MyConString)
        Dim WS As New wsGD.Service

        lblcreadapor.Text = ""
        lblNombreEstadoGuia.Text = ""
        LblGuia.Text = "S"
        MensajeError = ""
        EstadoAnterior = ""

        Dim dt As New DataTable
        cargar.ejecuta_query_dt("Select  isnull(GuiaGenerada,0), CodigoEstadoEntregaFactura, CodigoEmpresaDeEntrega from Factura Where CodigoFactura = " & txtCodigoFactura.Text, dt, MyConString)
        If dt.Rows.Count > 0 Then
            If dt.Rows(0).Item(0).ToString.Trim.Length > 0 Then
                GuiaGenerada = CBool(dt.Rows(0).Item(0).ToString.Trim)
            End If
            If dt.Rows(0).Item(1).ToString.Trim.Length > 0 Then
                CodigoEstadoEntregaFactura = CInt(dt.Rows(0).Item(1).ToString.Trim)
            Else
                CodigoEstadoEntregaFactura = 0
            End If

            If GuiaGenerada = True And CodigoEstadoEntregaFactura = 6 Then
                EstadoAnterior = "DD"
            End If

            If dt.Rows(0).Item(2).ToString.Trim.Length > 0 Then
                CodigoEmpresaDeEntrega = CInt(dt.Rows(0).Item(2).ToString.Trim)
            End If
        End If

        If (GuiaGenerada = True And CodigoEmpresaDeEntrega = 2) Or CodigoEmpresaDeEntrega = 2 Then
            If CodigoEstadoEntregaFactura <> 6 Then
                fuDevolverEstado(LblCodigoDeRastreo.Text, EstadoAnterior)

                If EstadoAnterior = "Error al consultar" Or EstadoAnterior = "" Then
                    If CodigoEstadoEntregaFactura = 0 And GuiaGenerada = True Then
                        LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque no se puede consultar su estado actual."
                        Return
                    ElseIf CodigoEstadoEntregaFactura <> 1 And CodigoEstadoEntregaFactura <> 0 Then
                        LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque ya fue enviada a Cargo Expreso."
                        Return
                    Else
                        EstadoAnterior = "SR"
                    End If
                ElseIf EstadoAnterior <> "SR" And EstadoAnterior <> "DD" And EstadoAnterior <> "NM" And EstadoAnterior <> "AN" Then
                    LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque ya fue enviada a Cargo Expreso."
                    Return
                End If
            End If
        ElseIf CodigoEmpresaDeEntrega = 6 Then
            Dim informacion As wsGD.EstadoProductoEnvia = WS.ObtenerEstadoGuia(LblCodigoDeRastreo.Text)
            If informacion.Mensaje.Equals("Exito") Then
                If informacion.paqueteEstado.ToString <> "1" And informacion.paqueteEstado.ToString <> "7" And informacion.paqueteEstado.ToString <> "21" Then
                    LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque ya fue enviada a Envia."
                    Return
                End If
                EstadoAnterior = informacion.paqueteEstado.ToString
            Else
                If CodigoEstadoEntregaFactura = 0 And GuiaGenerada = True Then
                    LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque no se puede consultar su estado actual."
                    Return
                ElseIf CodigoEstadoEntregaFactura <> 1 And CodigoEstadoEntregaFactura <> 0 Then
                    LblRespuesta.Text = "ERROR: No se puede eliminar esta guía porque ya fue enviada a Envia."
                    Return
                End If
            End If
        End If
        Consulta.Clear()
        Consulta.AppendLine("select COUNT(1) from Cobro where CodigoFactura = " & txtCodigoFactura.Text & " and COD = 1 and FechaConfirmacion is not null and Estado = 1")
        If cargar.retornarentero(Consulta.ToString, MyConString) = 0 Then
            If Validar_Ventas_Anuladas_Eliminar_Guia() = True Then
                If GuiaGenerada = True And CodigoEmpresaDeEntrega = 2 Then 'guía generada por cargo expreso, eliminarla del web service de cargo expreso
                    If AnularGuia(LblCodigoDeRastreo.Text, MensajeError, EstadoAnterior) = True Then
                        Exito = True
                    Else
                        Exito = False
                    End If
                ElseIf CodigoEmpresaDeEntrega = 6 And EstadoAnterior = "1" Then
                    MensajeError = WS.CancelarGuiaEnvia(LblCodigoDeRastreo.Text)
                    If MensajeError.Equals("Exito") Then
                        Exito = True
                    Else
                        Exito = False
                    End If
                Else 'guía se ingresó manualmente
                    Exito = True
                End If

                If Exito = True Then
                    Try
                        Conn.Open()
                        myTrans = Conn.BeginTransaction()

                        Consulta.Clear()
                        Consulta.AppendLine("update venta set Guia = NULL, CodigoEstadoEntrega = 4 ")
                        Consulta.AppendLine(" where CodigoFactura = " & txtCodigoFactura.Text)

                        cargar.insertarmodificareliminar_transaccion(Consulta.ToString, Conn, myTrans)

                        Consulta.Clear()
                        Consulta.AppendLine("INSERT INTO GuiaEliminada ")
                        Consulta.AppendLine(" ( ")
                        Consulta.AppendLine("CodigoFactura, ")
                        Consulta.AppendLine("NumeroDeGuia, ")
                        Consulta.AppendLine("CodigoEstadoEntregaFactura, ")
                        Consulta.AppendLine("FechaRecepcionEmpresaDeEntrega, ")
                        Consulta.AppendLine("CodigoEmpresaDeEntrega, ")
                        Consulta.AppendLine("CodigoUsuario, ")
                        Consulta.AppendLine("FechaEliminacion ")
                        Consulta.AppendLine(") ")
                        Consulta.AppendLine("SELECT ")
                        Consulta.AppendLine("CodigoFactura,")
                        Consulta.AppendLine("CodigoDeRastreo, ")
                        Consulta.AppendLine("CodigoEstadoEntregaFactura, ")
                        Consulta.AppendLine("FechaRecepcionEmpresaDeEntrega, ")
                        Consulta.AppendLine("CodigoEmpresaDeEntrega, ")
                        Consulta.AppendLine(CInt(Session("CodigoUsuario")) & "AS CodigoUsuario,")
                        Consulta.AppendLine("GETDATE() AS FechaEliminacion ")
                        Consulta.AppendLine("FROM Factura ")
                        Consulta.AppendLine("WHERE CodigoFactura = " & txtCodigoFactura.Text)

                        cargar.insertarmodificareliminar_transaccion(Consulta.ToString, Conn, myTrans)

                        Consulta.Clear()
                        Consulta.AppendLine("UPDATE Factura SET ")
                        Consulta.AppendLine("CodigoDeRastreo = NULL, ")
                        Consulta.AppendLine("FechaGuia = NULL, ")
                        Consulta.AppendLine("NumeroManifiesto = NULL, ")
                        Consulta.AppendLine("GuiaGenerada = NULL, ")
                        Consulta.AppendLine("FechaGeneracionGuia = NULL, ")
                        Consulta.AppendLine("CodigoEstadoEntregaFactura = NULL, ")
                        Consulta.AppendLine("FechaRecepcionEmpresaDeEntrega = NULL, ")
                        Consulta.AppendLine("CodigoEmpresaDeEntrega = NULL, ")
                        Consulta.AppendLine("CodigoUsuarioGuia= NULL ")
                        Consulta.AppendLine("WHERE CodigoFactura = " & txtCodigoFactura.Text)

                        cargar.insertarmodificareliminar_transaccion(Consulta.ToString, Conn, myTrans)

                        Consulta.Clear()
                        Consulta.AppendLine("UPDATE Cobro SET  COD = null, ")
                        Consulta.AppendLine("CodigoDeRastreo = NULL ")
                        Consulta.AppendLine("WHERE CodigoCobro IN ( ")
                        Consulta.AppendLine("SELECT c.CodigoCobro ")
                        Consulta.AppendLine("FROM Cobro c ")
                        Consulta.AppendLine("WHERE ")
                        Consulta.AppendLine("c.CodigoFactura = " & txtCodigoFactura.Text)
                        Consulta.AppendLine(")")

                        cargar.insertarmodificareliminar_transaccion(Consulta.ToString, Conn, myTrans)
                        Dim rootpath As String = Server.MapPath("") 'path a la raíz del proyecto
                        Dim ruta As String = rootpath & "\Guias\" & LblCodigoDeRastreo.Text & ".pdf"

                        If System.IO.File.Exists(ruta) = True Then
                            System.IO.File.Delete(ruta)
                        End If

                        myTrans.Commit()

                        DdlEmpresaDeEntrega.SelectedValue = "0"
                        ActualizarEmpresaEntrega(cargar, MyConString)
                        LblCodigoDeRastreo.Text = ""
                        txtCodigoDeRastreo.Text = ""
                        HlkImprimir_Guia.NavigateUrl = ""
                        HlkImprimir_Guia.Visible = False

                        LblRespuesta.Text = "Se quitó número de guía en las ventas de la factura "

                        BtnGenerarGuia.Visible = True
                        BtnEliminarGuia.Visible = False
                        txtCodigoDeRastreo.Visible = True
                        txtCodigoDeRastreo.ReadOnly = False

                        If LblGuiasAnuladas.Text = "" Then
                            LblGuiasAnuladas.Text = "Guías Eliminadas: " & LblCodigoDeRastreo.Text
                        Else
                            LblGuiasAnuladas.Text = LblGuiasAnuladas.Text & ", " & LblCodigoDeRastreo.Text
                        End If

                        LblGuiasAnuladas.Text = "Guías Eliminadas: " & cargar.retornarcadena("Select dbo.Lista_Valores(12,'" & txtCodigoFactura.Text & "','','','')", MyConString)

                    Catch ex As Exception
                        myTrans.Rollback()
                        LblRespuesta.Text = "No se logro eliminar la guia ERROR: " & ex.ToString
                    Finally
                        Conn.Close()
                    End Try
                Else
                    LblRespuesta.Text = MensajeError
                End If 'Anular Guia
            Else
                LblRespuesta.Text = "No se puede eliminar guía por que la factura ya tiene ventas entregadas"
            End If
        Else
            LblRespuesta.Text = "No se puede eliminar guía por que hay cobros en efectivo confirmados"
        End If
        btnImprimirGuiaGT.Visible = False
    End Sub
#End Region
#End Region
</script>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <script type="text/javascript" src="https://code.jquery.com/jquery-3.4.1.min.js"></script>
    <script type="text/javascript">

        function openInNewTab2(href) {
            Object.assign(document.createElement('a'), {
                target: '_blank',
                href: href,
            }).click();
        }

        function DissableButtons() {
            setTimeout(function () {
                var ButtonsColl = document.getElementsByTagName('input');
                for (i = 0; i < ButtonsColl.length; i++) {
                    if (ButtonsColl[i].getAttribute('type') == 'submit') {
                        ButtonsColl[i].disabled = true;
                    }
                }
            }, 50)
            return false;
        }
    </script>
    <div id="body" align="right">
        <div id="columnleft">

            <div class="leftblock" align="left">
                <table>
                    <tr>
                        <td align="center" style="width: 217px">
                            <asp:Label ID="Label2" runat="server" Text="Ventas" Font-Bold="True"></asp:Label>
                        </td>
                    </tr>
                </table>
                <asp:XmlDataSource ID="XmlDataSource1" runat="server"
                    DataFile="~/MenuVentas.xml" XPath="/*/*"></asp:XmlDataSource>
                <asp:TreeView ID="TreeView1" DataSourceID="XmlDataSource1" runat="server"
                    AutoGenerateDataBindings="True">
                    <DataBindings>
                        <asp:TreeNodeBinding DataMember="menu" TextField="name" NavigateUrlField="url" />
                    </DataBindings>
                </asp:TreeView>
            </div>
        </div>
        <!--end columnleft-->


        <!--Start of right column-->

        <div id="columnright" align="right">
            <div class="rightblock" align="center" style="float: right">
                <asp:Label ID="Label1" runat="server" Font-Bold="True" Font-Size="14pt"
                    Text="Verificación de empaque"></asp:Label>
                <br />

                <asp:Label ID="LblError" runat="server" ForeColor="Red"></asp:Label>
                <br />

                <div id="parent_container" runat="server" visible="True" style="font-size:13px;">
                    Orden:
                    <asp:TextBox ID="txtCodigoFactura" runat="server" Height="22px" Width="184px"></asp:TextBox>
                    <br />
                    <br />
                    <asp:Button ID="btnAceptar" runat="server" Text="Aceptar" Height="40px" Width="90px" OnClick="btnAceptar_Click" OnClientClick="DissableButtons()" Font-Size="13pt" />
                    <br />
                    <table style="width: 100%">
                        <tr>
                            <td style="width: 75%; text-align: center;"></td>
                            <td style="width: 25%; text-align: center;">
                                <asp:Label ID="lblFormaDeEnvio" runat="server" Text="Label"></asp:Label>
                            </td>
                        </tr>
                    </table>
                    <br />
                    <asp:GridView ID="GdUbicacion" runat="server" AutoGenerateColumns="False" OnRowDataBound="GdUbicacion_RowDataBound" HorizontalAlign="Center">
                        <Columns>
                            <asp:BoundField DataField="UPC" HeaderText="UPC">
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:BoundField>
                            <asp:BoundField DataField="Cantidad" HeaderText="Cantidad">
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:BoundField>
                            <asp:BoundField DataField="Nombre" HeaderText="Producto Nombre">
                                <FooterStyle Wrap="True" />
                                <HeaderStyle Wrap="True" />
                                <ItemStyle HorizontalAlign="Center" Wrap="True" />
                            </asp:BoundField>
                            <asp:ImageField DataImageUrlField="Foto" HeaderText="Foto">
                                <ControlStyle Width="100px" />
                            </asp:ImageField>
                            <asp:TemplateField HeaderText="Verificar Producto" ControlStyle-Width="80px">
                                <ItemTemplate>
                                    <asp:TextBox ID="TxtVerificaProducto" OnTextChanged="TxtVerificaProducto_TextChanged" AutoPostBack="True" runat="server" onkeydown="readOnlyFiel_down(event, this);" OnKeyUp="readOnlyField(this);" oncontextmenu="readOnlyFieldMouse(event);"></asp:TextBox>
                                    
                                </ItemTemplate>
                                <ControlStyle Width="80px"></ControlStyle>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:CheckBoxField DataField="Verificado" HeaderText="Verificado" ItemStyle-HorizontalAlign="Center">
                                <ItemStyle HorizontalAlign="Center"></ItemStyle>
                            </asp:CheckBoxField>
                            <asp:BoundField DataField="CodigoVenta" HeaderText="Codigo Venta" />
                            <asp:BoundField DataField="CodigoFactura" HeaderText="Codigo Factura" />
                            <asp:BoundField DataField="Escaneos" HeaderText="Escaneos" ItemStyle-HorizontalAlign="Center" />
                            <asp:BoundField DataField="CodigoProducto" HeaderText="Codigo Producto">
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:BoundField>
                            <asp:ImageField DataImageUrlField="EmpaqueRegalo" HeaderText="Empaque de regalo" ItemStyle-HorizontalAlign="Center" NullDisplayText="Sin Empaque"></asp:ImageField>
                        </Columns>
                    </asp:GridView>
                    <asp:Label ID="LblCodigoVenta" runat="server" Visible="False"></asp:Label>
                    <asp:Label ID="LblCodigoCliente" runat="server" Visible="False"></asp:Label>
                    <asp:Label ID="LblGuia" runat="server" Visible="False"></asp:Label>
                    <asp:Label ID="LblPila" runat="server" Visible="False"></asp:Label>
                    <br />
                    <br />

                    <br />
                    <asp:Label ID="Label4" runat="server" Font-Bold="True" Text="Datos de guía" Font-Size="13pt"></asp:Label>
                    <br />
                    <asp:Panel ID="Panel1" BorderStyle="Solid" runat="server" DefaultButton="BtnGuardarGuia" Height="460px" Width="689px">
                        <br />
                        <table style="font-size:13px;">
                            <tr>
                                <td colspan="2">Número de guía: <br/>
                                    <asp:Label ID="LblCodigoDeRastreo" runat="server"></asp:Label>
                                    <br/>
                                    <asp:RegularExpressionValidator ID="RegularExpressionValidator13" runat="server" ControlToValidate="txtCodigoDeRastreo" Display="Dynamic" ErrorMessage="Debe de ingresar guía" ForeColor="Red" ValidationExpression="[A-Za-z0-9_]+">*</asp:RegularExpressionValidator>
                                    <br/> 
                                    <asp:Label ID="lblcreadapor" runat="server"></asp:Label>
                                    <br/>
                                    <asp:Label ID="lblNombreEstadoGuia" runat="server" />
                                    <br/>
                                    <asp:Label ID="lblFechaEntrega" runat="server"></asp:Label>
                                    <br/><br/>
                                </td>
                                <td>
                                    <asp:CheckBox ID="noEnviarCorreos" runat="server" Text="No Enviar Correos" Visible="False" />
                                </td>
                                <td style="width: 116px">
                                    <asp:CheckBox ID="chkNoGenerarGuia" runat="server" AutoPostBack="True" OnCheckedChanged="chkNoGenerarGuia_CheckedChanged" Text="No generar guía" Visible="False" />
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2" style="font-size:14px;">Observaciones guía:<br/>
                                    <asp:TextBox ID="txtObservacionesGuia" runat="server" Height="75px" onkeypress="return this.value.length&lt;=110" TextMode="MultiLine" Width="285px"></asp:TextBox>
                                </td>
                                <td colspan="2" style="font-size:14px;"">Dirección de entrega: <br/>
                                    <asp:TextBox ID="TxtDireccionEntrega" runat="server" Font-Size="13pt" Height="75px" ReadOnly="True" TabIndex="2" TextMode="MultiLine" Width="285px"></asp:TextBox>
                                </td>
                            </tr>
                            <tr>
                                <td>Empresa de envío: <br/>
                                    
                                    <asp:DropDownList ID="DdlEmpresaDeEntrega" runat="server" AutoPostBack="True" OnSelectedIndexChanged="DdlEmpresaDeEntrega_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </td>
                                <td style="font-size:14px;"">Departamento: <br/>
                                    <asp:DropDownList ID="DdlDepartamento" runat="server" AutoPostBack="True" Enabled="False" Height="30px">
                                    </asp:DropDownList>
                                </td>
                                <td>Municipio:<br/>
                                    <asp:DropDownList ID="DdlMunicipio" runat="server" AutoPostBack="True" Enabled="False" Height="30px" OnSelectedIndexChanged="DdlMunicipio_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </td>
                                <td style="width: 116px">
                                    <asp:Button ID="BtnGenerarGuia" runat="server" Height="30px" OnClick="BtnGenerarGuia_Click" OnClientClick="DissableButtons()" Text="Generar guía" Width="110px" BackColor="#EFF4EC" />
                                    </td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <asp:Button ID="BtnEliminarGuia" runat="server" OnClick="BtnEliminarGuia_Click" Text="Eliminar guía" OnClientClick="DissableButtons()" BackColor="#F5EBEB" Height="30px" Width="110px"/>
                                    <br />
                                    <asp:Label ID="LblGuiasAnuladas" runat="server"></asp:Label>
                                    <br />
                                </td>
                                
                                <td>
                                    <asp:TextBox ID="txtCodigoDeRastreo" runat="server" Height="15px" ReadOnly="True" Width="175px"></asp:TextBox>
                                </td>
                                <td style="width: 116px">
                                    <asp:Button ID="BtnGuardarGuia" runat="server" Height="30px" OnClick="BtnGuardarGuia_Click" OnClientClick="DissableButtons()" Text="Guardar guía" Width="110px" UseSubmitBehavior="false" />
                                </td>
                            </tr>
                            <tr>
                                <td class="auto-style7" style="height: 37px">
                                    <asp:Label ID="LblEstadoGuia" runat="server" Visible="False"></asp:Label>
                                </td>
                                <td class="auto-style7" style="height: 37px">
                                    &nbsp;</td>
                                <td class="auto-style7" style="height: 37px">
                                    <asp:HyperLink ID="HlkImprimir_Guia" runat="server" Target="_blank">Imprimir guía</asp:HyperLink>
                                </td>

                                <td class="auto-style7" style="height: 37px; width: 116px;">
                                    <asp:Button Text="Imprimir Guia" ID="btnImprimirGuiaGT" OnClick="btnImprimirGuiaGT_Click" runat="server" Height="30px" Width="110px" />
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    <asp:Label ID="lblMensajeGuia" runat="server" Font-Size="Small" ForeColor="Red"></asp:Label>
                                </td>
                                <td colspan="2">
                                    &nbsp;</td>
                            </tr>
                            <tr>
                                <td colspan="5" style="text-align: center;">
                                    <center>
                                        <asp:TextBox Id="base64firma" runat="server" Style="visibility: hidden; width: 1px"></asp:TextBox>
                                        <asp:Label ID="LblRespuesta" runat="server" Font-Size="Small" ForeColor="Red"></asp:Label>
                                    </center>
                                </td>
                            </tr>
                        </table>

                    </asp:Panel>
                    <br />
                    <br />
                    <table class="auto-style4" style="width: 658px">
                        <tr>
                            <td>
                                <asp:TextBox ID="TxtCorreoCliente" runat="server" TabIndex="6" ReadOnly="True" Visible="False"></asp:TextBox>
                            </td>

                            <td>
                                <asp:TextBox ID="TxtNombreCliente" runat="server" TabIndex="1" Visible="False"></asp:TextBox>
                            </td>
                            <td>
                                <asp:TextBox ID="TxtTelefonos" runat="server" Visible="False"></asp:TextBox>
                                &nbsp;<asp:TextBox ID="TxtTelefonos2" runat="server" Width="70px" Visible="False"></asp:TextBox>
                            </td>
                            <td>
                                <asp:TextBox ID="TxtNitCliente" runat="server" TabIndex="3" Visible="False"></asp:TextBox>
                            </td>
                        </tr>
                        <tr>
                            <td class="auto-style6" style="height: 52px">
                                <asp:Label ID="lblCantidadDeCompras" runat="server" Visible="False"></asp:Label>
                            </td>
                            <td style="height: 52px">
                                <asp:TextBox ID="TxtNombreFactura" runat="server" TabIndex="4" Visible="False"></asp:TextBox>
                            </td>
                            <td class="auto-style6" style="height: 52px">
                                <asp:TextBox ID="TxtFechaGuia" runat="server" ReadOnly="True" Visible="False"></asp:TextBox>
                            </td>
                            <td style="height: 52px">
                                <asp:TextBox ID="TxtDireccionCliente" runat="server" TabIndex="5" Visible="False" Font-Size="12pt" Height="42px" Width="178px"></asp:TextBox>
                            </td>
                            <td style="height: 52px">
                                <asp:TextBox ID="TxtFechaFactura" runat="server" ReadOnly="True" Visible="False"></asp:TextBox>
                            </td>
                        </tr>
                    </table>
                </div>
            </div>
        </div>

        <asp:Table ID="TablaFactura" runat="server">
        </asp:Table>
    </div>
</asp:Content>