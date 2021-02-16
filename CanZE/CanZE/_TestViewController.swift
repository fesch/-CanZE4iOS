//
//  TestViewController.swift
//  CanZE
//
//  Created by Roberto Sonzogni on 22/12/20.
//

import CoreBluetooth
import SystemConfiguration
import UIKit

class _TestViewController: UIViewController {
    enum PickerPhase: String {
        case PERIPHERAL
        case SERVICES
        case WRITE_CHARACTERISTIC
        case READ_CHARACTERISTIC
    }

    var pickerPhase: PickerPhase = .PERIPHERAL

    enum BlePhase: String {
        case DISCOVER
        case DISCOVERED
    }

    var blePhase: BlePhase = .DISCOVER

    var arraySequenze: [Sequence] = []

    @IBOutlet var seg: UISegmentedControl!
    // @IBOutlet var tf: UITextField!
    @IBOutlet var tv: UITextView!

    @IBOutlet var pickerView: UIView!
    @IBOutlet var picker: UIPickerView!
    @IBOutlet var btn_PickerCancel: UIButton!
    @IBOutlet var btn_PickerDone: UIButton!
    var tmpPickerIndex = 0

    let ud = UserDefaults.standard

    var centralManager: CBCentralManager!
    var peripheralsDic: [String: BlePeripheral]!
    var selectedPeripheral: BlePeripheral!
    var selectedService: CBService!
    var selectedWriteCharacteristic: CBCharacteristic!
    var selectedReadCharacteristic: CBCharacteristic!
    var timeoutTimerBle: Timer!

    var peripheralsArray: [BlePeripheral]!
    var servicesArray: [CBService]!
    var characteristicArray: [CBCharacteristic]!

    // WIFI
    var inputStream: InputStream!
    var outputStream: OutputStream!
    let maxReadLength = 4096
    var timeoutTimerWifi: Timer!

    let test: [String] = ["atz", "ate0", "ats0", "atsp6", "atat1", "atcaf0", "atsh7e4", "atfcsh7e4", "03222006", "atcra699", "atma", "atar", "!?"] // , "!atz!ate0!ats0!atsp6!atat1"]
    var indiceTest = 0

    // queue
    let autoInitElm327: [String] = ["ate0", "ats0", "ath0", "atl0", "atal", "atcaf0", "atfcsh77b", "atfcsd300000", "atfcsm1", "atsp6"]
    var queue: [String] = []
    var timeoutTimer: Timer!
    var lastRxString = ""
    var lastId = -1

    // queue2
    var queue2: [Sequence] = []
    var indiceCmd = 0

    var fieldResult: [String: Double] = [:]

    var deviceIsInitialized = false

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(received(notification:)), name: Notification.Name("received"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(received2(notification:)), name: Notification.Name("received2"), object: nil)

        if seg.selectedSegmentIndex == 0 || seg.selectedSegmentIndex == 1 {
            Globals.shared.deviceType = .ELM327
        } else if seg.selectedSegmentIndex == 2 || seg.selectedSegmentIndex == 3 {
            Globals.shared.deviceType = .CANSEE
        }

        title = "TEST !"

        // Do any additional setup after loading the view.

        // title = Bundle.main.infoDictionary![kCFBundleNameKey as String] as? String

        /*
         // da mostrare solo se non pagina singola
         let backButton = UIBarButtonItem()
         backButton.title = "back"
         backButton.tintColor = UIColor(white: 0.15, alpha: 1)
         navigationController?.navigationBar.topItem?.backBarButtonItem = backButton
          */

        view.backgroundColor = UIColor(white: 0.9, alpha: 1)

        tv.text = ""
        tv.layoutManager.allowsNonContiguousLayout = false
        // tf.text = "ATI"
        seg.selectedSegmentIndex = 0

        var f = pickerView.frame
        f.origin.y = view.frame.height - f.size.height
        pickerView.frame = f

        //        serviceCBUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")

        peripheralsDic = [:]
        peripheralsArray = []
        servicesArray = []
        characteristicArray = []

        pickerView.alpha = 0
        pickerPhase = .PERIPHERAL
        picker.delegate = self
        picker.dataSource = self
        picker.reloadAllComponents()
        btn_PickerDone.setTitle("select peripheral", for: .normal)

        // wifi
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveFromWifiDongle(notification:)), name: Notification.Name("didReceiveFromWifiDongle"), object: nil)

        //        checkReachable()
        //        setReachabilityNotifier()
    }

    // MARK: DONGLE

    // DONGLE
    // DONGLE
    // DONGLE
    @IBAction func btnConnect() {
        deviceIsInitialized = false
        // tf.resignFirstResponder()
        switch seg.selectedSegmentIndex {
        case 0:
            // ELM327 BLE
            blePhase = .DISCOVER
            pickerPhase = .PERIPHERAL
            Globals.shared.deviceType = .ELM327
            Globals.shared.deviceConnection = .BLE
            connectBle()
        case 1:
            // ELM327 WIFI
            Globals.shared.deviceType = .ELM327
            Globals.shared.deviceConnection = .WIFI
            connectWifi()
        case 2:
            // CanSee BLE
            break
        case 3:
            // CanSee WIFI
            break
        default:
            break
        }
    }

    @IBAction func btnDisconnect() {
        deviceIsInitialized = false
        // tf.resignFirstResponder()
        switch seg.selectedSegmentIndex {
        case 0:
            // ELM327 BLE
            disconnectBle()
        case 1:
            // ELM327 WIFI
            disconnectWifi()
        case 2:
            // CanSee BLE
            break
        case 3:
            // CanSee WIFI
            break
        default:
            break
        }
    }

    func write(s: String) {
        switch Globals.shared.deviceConnection {
        case .BLE:
            writeBle(s: s)
        case .WIFI:
            writeWifi(s: s)
        case .HTTP:
            writeHttp(s: s)
        default:
            debug("can't find device connection")
        }
    }

    func write_(s: String) {
        // tf.resignFirstResponder()
        switch seg.selectedSegmentIndex {
        case 0:
            // ELM327 BLE
            writeBle(s: s)
        case 1:
            // ELM327 WIFI
            writeWifi(s: s)
        case 2:
            // CanSee BLE
            break
        case 3:
            // CanSee WIFI
            break
        default:
            break
        }
    }

    // ELM327 BLE
    // ELM327 BLE
    // ELM327 BLE
    func connectBle() {
        peripheralsDic = [:]
        peripheralsArray = []
        selectedPeripheral = nil
        if blePhase == .DISCOVERED {
            timeoutTimerBle = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { timer in
                if self.selectedPeripheral == nil {
                    // timeout
                    self.centralManager.stopScan()
                    timer.invalidate()
                    self.view.hideAllToasts()
                    self.view.makeToast("can't connect to ble device: TIMEOUT")
                }
            })
        }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func disconnectBle() {
        if selectedPeripheral != nil, selectedPeripheral.blePeripheral != nil {
            centralManager.cancelPeripheralConnection(selectedPeripheral.blePeripheral)
            selectedPeripheral.blePeripheral = nil
            selectedService = nil
            selectedReadCharacteristic = nil
            selectedWriteCharacteristic = nil
        }
    }

    func writeBle(s: String) {
        if selectedWriteCharacteristic != nil {
            let ss = s.appending("\r")
            if let data = ss.data(using: .utf8) {
                if selectedWriteCharacteristic.properties.contains(.write) {
                    selectedPeripheral.blePeripheral.writeValue(data, for: selectedWriteCharacteristic, type: .withResponse)
                    debug("> \(s)")
                } else if selectedWriteCharacteristic.properties.contains(.writeWithoutResponse) {
                    selectedPeripheral.blePeripheral.writeValue(data, for: selectedWriteCharacteristic, type: .withoutResponse)
                    debug("> \(s)")
                } else {
                    debug("can't write to characteristic")
                }
            } else {
                debug("data is nil")
            }
        }
    }

    // ELM327 WIFI
    // ELM327 WIFI
    // ELM327 WIFI
    func connectWifi() {
        if Globals.shared.deviceWifiAddress == "" || Globals.shared.deviceWifiPort == "" {
            view.hideAllToasts()
            view.makeToast("_Please configure")
            return
        }

        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           Globals.shared.deviceWifiAddress as CFString,
                                           UInt32(Globals.shared.deviceWifiPort)!,
                                           &readStream,
                                           &writeStream)

        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream.delegate = self
        outputStream.delegate = self

        inputStream.schedule(in: RunLoop.current, forMode: .default)
        outputStream.schedule(in: RunLoop.current, forMode: .default)

        inputStream.open()
        outputStream.open()

        print("inputStream \(decodeStatus(status: inputStream.streamStatus))")
        print("outputStream \(decodeStatus(status: outputStream.streamStatus))")

        var contatore = 5
        timeoutTimerWifi = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
            print(contatore)

            if self.inputStream.streamStatus == .open, self.outputStream.streamStatus == .open {
                // connesso
                self.timeoutTimerWifi.invalidate()
                self.timeoutTimerWifi = nil
            }

            if contatore < 1 {
                // NON connesso
                self.timeoutTimerWifi.invalidate()
                self.timeoutTimerWifi = nil
                self.disconnectWifi()
                self.view.hideAllToasts()
                self.view.makeToast("TIMEOUT")
            }

            contatore -= 1

        })
    }

    func disconnectWifi() {
        if inputStream != nil {
            inputStream.close()
            inputStream.remove(from: RunLoop.current, forMode: .default)
            inputStream.delegate = nil
            inputStream = nil
        }
        if outputStream != nil {
            outputStream.close()
            outputStream.remove(from: RunLoop.current, forMode: .default)
            outputStream.delegate = nil
            outputStream = nil
        }
    }

    func writeWifi(s: String) {
        if outputStream != nil {
            let s2 = s.appending("\r")
            let data = s2.data(using: .utf8)!
            data.withUnsafeBytes {
                guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    debug("Error")
                    return
                }
                debug("> \(s)")
                outputStream.write(pointer, maxLength: data.count)
            }
        }
    }

    // ricezione dati wifi
    @objc func didReceiveFromWifiDongle(notification: Notification) {
        let dic = notification.object as? [String: Any]
        if dic != nil, dic?.keys != nil {
            for k in dic!.keys {
                let ss = dic![k] as! String
                NotificationCenter.default.post(name: Notification.Name("received"), object: ["tag": ss])
            }
        }
    }

    func decodeStatus(status: Stream.Status) -> String {
        switch status {
        case .notOpen:
            return "notOpen"
        case .opening:
            return "opening"
        case .open:
            return "open"
        case .reading:
            return "reading"
        case .writing:
            return "writing"
        case .atEnd:
            return "atEnd"
        case .closed:
            return "closed"
        case .error:
            return "error"
        @unknown default:
            fatalError()
        }
    }

    // http

    func writeHttp(s: String) {
        var request = URLRequest(url: URL(string: "\(Globals.shared.deviceHttpAddress)\(s)")!, timeoutInterval: 5)
        request.httpMethod = "GET"

        debug("> \(s)")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data else {
                print(String(describing: error))
                return
            }
//            print(data)
            let reply = String(data: data, encoding: .utf8)
            let reply2 = reply?.components(separatedBy: ",")
            if reply2?.count == 2 {
                var reply3 = reply2?.last
                if reply3!.contains("problem") {
                    reply3 = "ERROR"
                }
                let dic = ["tag": reply3]
                NotificationCenter.default.post(name: Notification.Name("received2"), object: dic)
            } else {
                self.debug(reply!)
            }
        }
        task.resume()
    }

    // BTN

    @IBAction func btnAutoInit() {
        queue = []
        for s in autoInitElm327 {
            queue.append(s)
        }
        processQueue()
    }

    @IBAction func btnSaveBleConnectionParams() {
//        ud.setValue(selectedPeripheral.blePeripheral.identifier.uuidString, forKey: "blePeripheral.identifier.uuidString")
//        ud.setValue(selectedService.uuid.uuidString, forKey: "selectedService.uuid.uuidString")
//        ud.setValue(selectedReadCharacteristic.uuid.uuidString, forKey: "selectedReadCharacteristic.uuid.uuidString")
//        ud.setValue(selectedWriteCharacteristic.uuid.uuidString, forKey: "selectedWriteCharacteristic.uuid.uuidString")

        ud.setValue(Globals.shared.deviceBleName.rawValue, forKey: AppSettings.SETTINGS_DEVICE_BLE_NAME)
        ud.setValue(Globals.shared.deviceBlePeripheralName, forKey: AppSettings.SETTINGS_DEVICE_BLE_PERIPHERAL_NAME)
        ud.setValue(Globals.shared.deviceBlePeripheralUuid, forKey: AppSettings.SETTINGS_DEVICE_BLE_PERIPHERAL_UUID)
        ud.setValue(Globals.shared.deviceBleServiceUuid, forKey: AppSettings.SETTINGS_DEVICE_BLE_SERVICE_UUID)
        ud.setValue(Globals.shared.deviceBleReadCharacteristicUuid, forKey: AppSettings.SETTINGS_DEVICE_BLE_READ_CHARACTERISTIC_UUID)
        ud.setValue(Globals.shared.deviceBleWriteCharacteristicUuid, forKey: AppSettings.SETTINGS_DEVICE_BLE_WRITE_CHARACTERISTIC_UUID)

        ud.synchronize()
        
        debug("\(Globals.shared.deviceBleName.rawValue)")
        debug(Globals.shared.deviceBlePeripheralName)
        debug(Globals.shared.deviceBlePeripheralUuid)
        debug(Globals.shared.deviceBleServiceUuid)
        debug(Globals.shared.deviceBleReadCharacteristicUuid)
        debug(Globals.shared.deviceBleWriteCharacteristicUuid)

    }

    @IBAction func btnLoadBleConnectionParams() {
        //        blePeripheral_identifier_uuidString = ud.string(forKey: "blePeripheral.identifier.uuidString") ?? ""
        //        selectedService_uuid_uuidString = ud.string(forKey: "selectedService.uuid.uuidString") ?? ""
        //        selectedReadCharacteristic_uuid_uuidString = ud.string(forKey: "selectedReadCharacteristic.uuid.uuidString") ?? ""
        //        selectedWriteCharacteristic_uuid_uuidString = ud.string(forKey: "selectedWriteCharacteristic.uuid.uuidString") ?? ""

        Globals.shared.deviceBleName = AppSettings.DEVICE_BLE_NAME(rawValue: ud.value(forKey: AppSettings.SETTINGS_DEVICE_BLE_NAME) as? Int ?? 0) ?? .NONE
        Globals.shared.deviceBlePeripheralName = ud.string(forKey: AppSettings.SETTINGS_DEVICE_BLE_PERIPHERAL_NAME) ?? ""
        Globals.shared.deviceBlePeripheralUuid = ud.string(forKey: AppSettings.SETTINGS_DEVICE_BLE_PERIPHERAL_UUID) ?? ""
        Globals.shared.deviceBleServiceUuid = ud.string(forKey: AppSettings.SETTINGS_DEVICE_BLE_SERVICE_UUID) ?? ""
        Globals.shared.deviceBleReadCharacteristicUuid = ud.string(forKey: AppSettings.SETTINGS_DEVICE_BLE_READ_CHARACTERISTIC_UUID) ?? ""
        Globals.shared.deviceBleWriteCharacteristicUuid = ud.string(forKey: AppSettings.SETTINGS_DEVICE_BLE_WRITE_CHARACTERISTIC_UUID) ?? ""

        debug("\(Globals.shared.deviceBleName.rawValue)")
        debug(Globals.shared.deviceBlePeripheralName)
        debug(Globals.shared.deviceBlePeripheralUuid)
        debug(Globals.shared.deviceBleServiceUuid)
        debug(Globals.shared.deviceBleReadCharacteristicUuid)
        debug(Globals.shared.deviceBleWriteCharacteristicUuid)

        blePhase = .DISCOVERED
        Globals.shared.deviceConnection = .BLE
        Globals.shared.deviceType = .ELM327
        if Globals.shared.deviceBlePeripheralName != "" {
            connectBle()
        } else {
            print("non configurato")
        }
    }

    @IBAction func btnTest() {
        // tf.resignFirstResponder()
        if indiceTest > test.count - 1 {
            indiceTest = 0
        }
        let s = test[indiceTest]
        write_(s: s)

        debug(s)

        indiceTest += 1
    }

    @IBAction func btnSend() {
        // tf.resignFirstResponder()
        //   if tf.text != nil {
        //        write_(s: tf.text!)
        //   }
    }

    // FUNZIONI FRAME

    @IBAction func requestIsoTpFrame() {
/*        if true { // TEST TEST TEST
//            lastId = -1
            queue = []
            if Utils.isPh2() {
                addField(Sid.EVC, intervalMs: 2000) // open EVC
            }

//            addField(Sid.MaxCharge, intervalMs: 5000)
            addField(Sid.UserSoC, intervalMs: 5000)
            addField(Sid.RealSoC, intervalMs: 5000)
//            addField(Sid.SOH, intervalMs: 5000) // state of health gives continuous timeouts. This frame is send at a very low rate
//            addField(Sid.RangeEstimate, intervalMs: 5000)
            addField(Sid.DcPowerIn, intervalMs: 5000) // virtual virtual virtual
//            addField(Sid.AvailableChargingPower, intervalMs: 5000)
//            addField(Sid.HvTemp, intervalMs: 5000)

//            addField(Sid.BatterySerial, intervalMs: 99999) // 7bb.6162.16      2ff
//            addField(Sid.Total_kWh, intervalMs: 99999) // 7bb.6161.120         1ff
//            addField(Sid.Counter_Full, intervalMs: 99999) //                   ff
//            addField(Sid.Counter_Partial, intervalMs: 99999) //                ff

            startQueue2()

        } else {
           // let field = Fields.getInstance.getBySID(Sid.UserSoC)

            //  print("\(field?.from ?? -1) \(field?.to ?? -1)")

            struct A {
                var a1 = ""
                var a2 = ""
            }
            var arr: [A] = []
            var a = A(a1: Sid.MaxCharge, a2: "05629018041AAAAA")
//            arr.append(a)
//            a = A(a1: Sid.UserSoC, a2: "622002130A")
//            arr.append(a)
//            a = A(a1: Sid.RealSoC, a2: "056290011843AAAA")
//            arr.append(a)
//            a = A(a1: Sid.SOH, a2: "0562900324ADAAAA")
//            arr.append(a)
//            a = A(a1: Sid.RangeEstimate, a2: "037F2231AAAAAAAA")
//            arr.append(a)
//            a = A(a1: Sid.DcPowerIn, a2: "")
//            arr.append(a)
//            a = A(a1: Sid.AvailableChargingPower, a2: "0562300F0000AAAA")
//            arr.append(a)
//            a = A(a1: Sid.HvTemp, a2: "0562901202B0AAAA")
//            arr.append(a)
            a = A(a1: Sid.BatterySerial, a2: "101462F19056463121414730303030362234393531353432")
            arr.append(a)
//            a = A(a1: Sid.Total_kWh, a2: "076292430018424E")
//            arr.append(a)
//            a = A(a1: Sid.Counter_Full, a2: "056292100019AAAA")
//            arr.append(a)
//            a = A(a1: Sid.Counter_Partial, a2: "0562921500BBAAAA")
//            arr.append(a)

            for s in arr {
                let nn = Notification.Name("a")
                let no = Notification(name: nn, object: ["sid": s.a1, "tag": s.a2], userInfo: nil)
                received2(notification: no)
                /*
                                let field = Fields.getInstance.getBySID(s.a1)

                                if field != nil, s.a2 != "" {
                                    print("\(field?.sid ?? "?") \(field?.name ?? "?")")
                                    tv.text += "\n\(field?.sid ?? "?") \(field?.name ?? "?")"

                                    if Globals.shared.deviceType == AppSettings.DEVICE_TYPE_ELM327 {
                                        field?.strVal = decodeIsoTp(elmResponse2: s.a2) // ""
                                        if field!.strVal.hasPrefix("7f") {
                                            debug( "error 7f")
                                        } else if field!.strVal == "" {
                                            debug( "empty")
                                        } else {
                                            let binString = getAsBinaryString(data: field!.strVal)
                                            onMessageCompleteEventField(binString_: binString, field: field!)
                                            if field!.isString() || field!.isHexString() {
                                                debug( "\(field!.strVal)")
                                            } else {
                                                debug( "\(String(format: "%.\(field!.decimals!)f", field!.getValue()))")
                                            }
                                        }
                                    } else if Globals.shared.deviceType == AppSettings.DEVICE_TYPE_CANSEE {
                                        let binString = getAsBinaryString(data: s.a2)
                                        onMessageCompleteEventField(binString_: binString, field: field!)

                                        if field!.isString() || field!.isHexString() {
                                            debug( "\(field!.strVal)")
                                        } else {
                                            debug( " \(String(format: "%.\(field!.decimals!)f", field!.getValue()))")
                                        }
                                    } else {
                                        debug( "device ?")
                                    }
                                } else {
                                    debug( "field \(s.a1) not found")
                                }
                 */
            }
        }*/
    }

    func addField(_ sid: String, intervalMs: Int) {
        if let field = Fields.getInstance.getBySID(sid) {
            if field.responseId != "999999" {
                //  addField(field:field, intervalMs: intervalMs)
                //   print("sid \(field?.from ?? -1)")
                requestIsoTpFrame(frame2: (field.frame)!, field: field)
            }
        } else {
//            MainActivity.debug(this.getClass().getSimpleName() + " (CanzeActivity): SID " + sid + " does not exist in class Fields");
//            MainActivity.toast(MainActivity.TOAST_NONE, String.format(Locale.getDefault(), MainActivity.getStringSingle(R.string.format_NoSid), this.getClass().getSimpleName(), sid));
        }
    }

    func requestIsoTpFrame(frame2: Frame, field: Field) {
        // TEST
        // TEST
        let frame = frame2
        if frame.sendingEcu.fromId == 0x18DAF1DA, frame.responseId == "5003" {
            let ecu = Ecus.getInstance.getByFromId(0x18DAF1D2)
            frame.sendingEcu = ecu
            frame.fromId = ecu.fromId
        }
        // TEST
        // TEST

        // print("\(frame.sendingEcu.name ?? "") \(frame.responseId ?? "")")

        if field.virtual {
//            var r = calcolaVirtual(field)
//            let dic = ["tag":r]
//            NotificationCenter.default.post(name: Notification.Name("received2"), object: dic)

            let virtualField = Fields.getInstance.getBySID(field.sid) as! VirtualField
            let fields = virtualField.getFields()
            for f in fields {
                if f.responseId != "999999" {
                    requestIsoTpFrame(frame2: (f.frame)!, field: f)
                }
            }
            let seq = queue2.last
            seq?.sidVirtual = field.sid
            return
        }

        let seq = Sequence()
//        seq.frame = frame
        seq.field = field

        if lastId != frame.fromId {
            if Globals.shared.deviceConnection == .HTTP {
                // i7ec,222002,622002
                let s = "?command=i\(String(format: "%02x", frame.fromId)),\(frame.getRequestId()),\(field.responseId ?? "")"
                seq.cmd.append(s)
                queue2.append(seq)
                return

            } else {
                if frame.isExtended() {
                    seq.cmd.append("atsp7")
                } else {
                    seq.cmd.append("atsp6")
                }
                seq.cmd.append("atcp\(frame.getToIdHexMSB())") // atcp18
                seq.cmd.append("atsh\(frame.getToIdHexLSB())") // atshdad2f1
                seq.cmd.append("atcra\(String(format: "%02x", frame.fromId))") // 18daf1d2
                seq.cmd.append("atfcsh\(String(format: "%02x", frame.getToId()))") // 18dad2f1
            }

            lastId = frame.fromId
        }

        // elm327.java

        // ISOTP outgoing starts here
        let outgoingLength = frame.getRequestId().count
//        var elmResponse = ""
        var elmCommand = ""
        if outgoingLength <= 14 {
            // SINGLE transfers up to 7 bytes. If we ever implement extended addressing (which is
            // not the same as 29 bits mode) this driver considers this simply data
            // 022104           ISO-TP single frame - length 2 - payload 2104, which means PID 21 (??), id 04 (see first tab).
            elmCommand = "0\(outgoingLength / 2)\(frame.getRequestId())" // 021003
            seq.cmd.append(elmCommand)
            // send SING frame.
            // elmResponse = sendAndWaitForAnswer(elmCommand, 0, false).replace("\r", "")
        } else {
            var startIndex = 0
            var endIndex = 12
            // send FRST frame.
            print(" send FRST frame")
            elmCommand = String(format: "1%03X", outgoingLength / 2) + frame.getRequestId().subString(from: startIndex, to: endIndex)
            seq.cmd.append(elmCommand)
            // flushWithTimeout(500, '>');
            ///                var elmFlowResponse = sendAndWaitForAnswer(elmCommand, 0, false).replace("\r", "")
            startIndex = endIndex
            if startIndex > outgoingLength {
                startIndex = outgoingLength
            }
            endIndex += 14
            if endIndex > outgoingLength {
                endIndex = outgoingLength
            }
            var next = 1
            while startIndex < outgoingLength {
                // prepare NEXT frame.
                elmCommand = String(format: "2%01X", next) + frame.getRequestId().subString(from: startIndex, to: endIndex)
                seq.cmd.append(elmCommand)
                // for the moment we ignore block size, just 1 or all. Also ignore delay
                ///                    if elmFlowResponse.startsWith("3000") {
                // The receiving ECU expects all data to be sent without further flow control,
                // the ELM still answers with at least a \n after each sent frame.
                // Since there are no further flow control frames, we just pretent the answer
                // of each frame is the actual answer and won't change the FlowResponse
                // flushWithTimeout(500, '>');
                ///                        elmResponse = sendAndWaitForAnswer(elmCommand, 0, false).replace("\r", "")
                ///                    } else if elmFlowResponse.startsWith("30") {
                // The receiving ECU expects the next frame of data to be sent, and it will
                // respond with the next flow control command, or the actual answer. We just
                // pretent the answer of the frame is both the actual answer as wel as the next
                // FlowResponse
                // flushWithTimeout(500, '>');
                ///                        elmFlowResponse = sendAndWaitForAnswer(elmCommand, 0, false).replace("\r", "")
                ///                        elmResponse = elmFlowResponse
                ///                    } else {
                ///                         return new Message(frame, "-E-ISOTP tx flow Error:" + elmFlowResponse, true)
            }
            startIndex = endIndex
            if startIndex > outgoingLength {
                startIndex = outgoingLength
            }
            endIndex += 14
            if endIndex > outgoingLength {
                endIndex = outgoingLength
            }
//            if next == 15 {
//                next = 0
//            } else {
                next += 1
//            }
        }

        queue2.append(seq)
    }

    func decodeIsoTp(elmResponse2: String) -> String { // TEST
        var hexData = ""
        var len = 0

        var elmResponse = elmResponse2

        // ISOTP receiver starts here
        // clean-up if there is mess around
        elmResponse = elmResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if elmResponse.starts(with: ">") {
            elmResponse = elmResponse.subString(from: 1)
        }

        /*    // quit on error conditions
         if (elmResponse.compareTo("CAN ERROR") == 0) {
             return new Message(frame, "-E-Can Error", true)
         } else if (elmResponse.compareTo("?") == 0) {
             return new Message(frame, "-E-Unknown command", true)
         } else if (elmResponse.compareTo("") == 0) {
             return new Message(frame, "-E-Empty result", true)
         }
         */
        // get type (first nibble of first line)
        switch elmResponse.subString(from: 0, to: 1) {
        case "0": // SINGLE frame
//                     try {
            len = Int(elmResponse.subString(from: 1, to: 2), radix: 16)!
            // remove 2 nibbles (type + length)
            hexData = elmResponse.subString(from: 2)
        // and we're done
//                     } catch (StringIndexOutOfBoundsException e) {
//                         return new Message(frame, "-E-ISOTP rx unexpected length of SING frame:" + elmResponse, true);
//                     } catch (NumberFormatException e) {
//                         return new Message(frame, "-E-ISOTP rx uninterpretable length of SING frame:" + elmResponse, true);

//        default:
//            print("altri casi ancora da implementare")
//            tv.text.append("\naltri casi ancora da implementare")
//            tv.scrollToBottom()
//        }

        case "1": // FIRST frame
            len = Int(elmResponse.subString(from: 1, to: 4), radix: 16)!
            // remove 4 nibbles (type + length)
            hexData = elmResponse.subString(from: 4)
            //                     } catch (StringIndexOutOfBoundsException e) {
            //                         return new Message(frame, "-E-ISOTP rx unexpected length of FRST frame:" + elmResponse, true);
            //                     } catch (NumberFormatException e) {
            //                         return new Message(frame, "-E-ISOTP rx uninterpretable length of FRST frame:" + elmResponse, true);
            //                     }
            // calculate the # of frames to come. 6 byte are in and each of the 0x2 frames has a payload of 7 bytes
            let framesToReceive = len / 7 // read this as ((len - 6 [remaining characters]) + 6 [offset to / 7, so 0->0, 1-7->7, etc]) / 7
            // get all remaining 0x2 (NEXT) frames

            // queue.append(framesToReceive)

            // TEST
            // TEST
            // TEST
            //  var lines0x1 = "" // sendAndWaitForAnswer(nil, 0, framesToReceive)
            //     "101462F19056463121414730303030362234393531353432"
            // lines0x1 = "62F19056463121414730303030362234393531353432"
            /*
             var fin = hexData.subString(from: 6, to: 12)
             var i = 0
             while i < framesToReceive {
                 let sub = hexData.subString(from: 14+i*16, to:  28+i*16)
                 fin.append(sub)
                 i += 1
             }
             hexData = fin
             */
            var fin = hexData.subString(from: 0, to: 12)
            var i = 0
            while i < framesToReceive {
                let sub = hexData.subString(from: 14 + i * 16, to: 28 + i * 16)
                fin.append(sub)
                i += 1
            }
            hexData = fin

            // TEST
            // TEST
            // TEST

        /*
            // split into lines with hex data
            let hexDataLines = lines0x1.components(separatedBy: "[\\r]+")
            var next = 1
            for hexDataLine_ in hexDataLines {
                // ignore empty lines
                var hexDataLine = hexDataLine_
                hexDataLine = hexDataLine.trimmingCharacters(in: .whitespaces)
                if hexDataLine.count > 2 {
                    // check the proper sequence
                    if hexDataLine.hasPrefix(String(format: "2%01X", next)) {
                        // cut off the first byte (type + sequence) and add to the result
                        hexData += hexDataLine.subString(from: 2)
                    } else {
                        //  return new Message(frame, "-E-ISOTP rx out of sequence:" + hexDataLine, true);
                    }
                    if next == 15 {
                        next = 0
                    } else {
                        next += 1
                    }
                }
            }
         */
        default: // a NEXT, FLOWCONTROL should not be received. Neither should any other string (such as NO DATA)
            // flushWithTimeout(400, '>');
            // return new Message(frame, "-E-ISOTP rx unexpected 1st nibble of 1st frame:" + elmResponse, true);
            print("-E-ISOTP rx unexpected 1st nibble of 1st frame")
        }
        // There was spurious error here, that immediately sending another command STOPPED the still not entirely finished ISO-TP command.
        // It was probably still sending "OK>" or just ">". So, the next command files and if it was i.e. an atcra f a free frame capture,
        // the following ATMA immediately overwhelmed the ELM as no filter was set.
        // As a solution, added this wait for a > after an ISO-TP command.

//             flushWithTimeout(400, '>');
        len *= 2

        // Having less data than specified in length is actually an error, but at least we do not need so substr it
        // if there is more data than specified in length, that is OK (filler bytes in the last frame), so cut those away
        hexData = (hexData.count <= len) ? hexData.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : hexData.subString(from: 0, to: len).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if hexData == "" {
//                 return new Message(frame, "-E-ISOTP rx data empty", true);
            print("-E-ISOTP rx data empty")
        } else {
//                 return new Message(frame, hexData.toLowerCase(), false);
            // print(hexData.lowercased())
        }

        return hexData.lowercased()
    }

    func onMessageCompleteEventField(binString_: String, field: Field) {
        var binString = binString_

        if binString.count >= field.to, field.responseId != "999999" {
            // parseInt --> signed, so the first bit is "cut-off"!
            //  try {
            binString = binString.subString(from: field.from, to: field.to + 1)
            if field.isString() {
                var tmpVal = ""
                var i = 0
                while i < binString.count {
                    let n = "0" + binString.subString(from: i, to: i + 8)
                    let nn = Int(n, radix: 2)
                    let c = UnicodeScalar(nn!)
                    tmpVal.append(String(c!))
                    i += 8
                }
                field.strVal = tmpVal.trim()
            } else if field.isHexString() {
                var tmpVal = ""
                var i = 0
                while i < binString.count {
                    let n = "0" + binString.subString(from: i, to: i + 8)
                    let nn = Int(n, radix: 2)
                    let c = UnicodeScalar(nn!)
                    let s = String(format: "%02X", c as! CVarArg)
                    tmpVal.append(s)
                    i += 8
                }
                field.strVal = tmpVal.trim()
            } else if binString.count <= 4 || binString.contains("0") {
                // experiment with unavailable: any field >= 5 bits whose value contains only 1's
                var val = 0 // long to avoid craze overflows with 0x8000 ofsets

                if field.isSigned(), binString.hasPrefix("1") {
                    // ugly method: flip bits, add a minus in front and subtract one
                    val = Int("-" + binString.replacingOccurrences(of: "0", with: "q").replacingOccurrences(of: "1", with: "0").replacingOccurrences(of: "q", with: "1"), radix: 2)! - 1
                } else {
                    val = Int("0" + binString, radix: 2)!
                }
                // MainActivity.debug("Value of " + field.getFromIdHex() + "." + field.getResponseId() + "." + field.getFrom()+" = "+val);
                // MainActivity.debug("Fields: onMessageCompleteEvent > "+field.getSID()+" = "+val);

                // update the value of the field. This triggers updating all of all listeners of that field
                field.value = Double(val)

            } else {
                field.value = Double.nan
            }

            // do field logging
//                if(MainActivity.fieldLogMode)
//                    FieldLogger.getInstance().log(field.getDebugValue());

//            } catch (Exception e)
//            {
//                MainActivity.debug("Message.onMessageCompleteEventField: Exception:");
//                MainActivity.debug(e.getMessage());
            // ignore
//            }
        }
        // update the fields last request date
        //  field.updateLastRequest();
    }

    var error = false
    func getAsBinaryString(data: String) -> String {
        // 629001266f
        // 0110001010010000000000010010011001101111

        var result = ""

        if !error {
//            let x = Int64(data, radix: 16)            // max data length:16 chars
//            result = String(x!, radix: 2)
            var d = data
            if d.count % 2 != 0 {
                d = "0" + d
            }
            result = d.hexaToBinary
            while result.count % 8 != 0 {
                result = "0" + result
            }
            // print(result)
        }
        return result
    }

    // VARIE

    @IBAction func segmentedValue() {
        // tf.resignFirstResponder()
        btnDisconnect()
        print(seg.selectedSegmentIndex)

        if seg.selectedSegmentIndex == 0 || seg.selectedSegmentIndex == 1 {
            Globals.shared.deviceType = .ELM327
        } else if seg.selectedSegmentIndex == 2 || seg.selectedSegmentIndex == 3 {
            Globals.shared.deviceType = .CANSEE
        }
    }

    // PICKER
    @IBAction func btnPickerCancel() {
        //    tf.resignFirstResponder()
        if pickerPhase == .PERIPHERAL {
            pickerView.alpha = 0

            tmpPickerIndex = 0
            selectedPeripheral = nil
            peripheralsArray = []
            picker.selectRow(0, inComponent: 0, animated: false)
            picker.reloadAllComponents()
            selectedPeripheral = nil

            centralManager.stopScan()

        } else if pickerPhase == .SERVICES {
            pickerPhase = .PERIPHERAL

            tmpPickerIndex = 0
            selectedService = nil
            servicesArray = []
            picker.selectRow(0, inComponent: 0, animated: false)
            picker.reloadAllComponents()
            btn_PickerDone.setTitle("select peripheral", for: .normal)

        } else if pickerPhase == .WRITE_CHARACTERISTIC {
            pickerPhase = .SERVICES

            tmpPickerIndex = 0
            selectedWriteCharacteristic = nil
            characteristicArray = []
            picker.selectRow(0, inComponent: 0, animated: false)
            picker.reloadAllComponents()
            btn_PickerDone.setTitle("select services", for: .normal)

        } else if pickerPhase == .READ_CHARACTERISTIC {
            pickerPhase = .WRITE_CHARACTERISTIC

            tmpPickerIndex = 0
            selectedReadCharacteristic = nil
            picker.selectRow(0, inComponent: 0, animated: false)
            picker.reloadAllComponents()
            btn_PickerDone.setTitle("select WRITE characteristic", for: .normal)
        }
    }

    @IBAction func btnPickerDone() {
        //    tf.resignFirstResponder()
        // print(tmpPickerIndex)
        if pickerPhase == .PERIPHERAL {
            if peripheralsArray.count > tmpPickerIndex {
                centralManager.stopScan()
                selectedPeripheral = peripheralsArray[tmpPickerIndex]
                Globals.shared.deviceBlePeripheralName = selectedPeripheral.blePeripheral.name ?? ""
                Globals.shared.deviceBlePeripheralUuid = selectedPeripheral.blePeripheral.identifier.uuidString
                debug("selected peripheral \(selectedPeripheral.blePeripheral.name ?? "?")")
                selectedPeripheral.blePeripheral.delegate = self
                centralManager.connect(selectedPeripheral.blePeripheral)
                btn_PickerDone.setTitle("select service", for: .normal)
            }
        } else if pickerPhase == .SERVICES {
            if servicesArray.count > tmpPickerIndex {
                pickerPhase = .WRITE_CHARACTERISTIC
                selectedService = servicesArray[tmpPickerIndex]
                Globals.shared.deviceBleServiceUuid = selectedService.uuid.uuidString
                debug("selected service \(selectedService.uuid)")
                characteristicArray = []
                selectedPeripheral.blePeripheral.discoverCharacteristics([selectedService.uuid], for: selectedService)
                btn_PickerDone.setTitle("select WRITE characteristic", for: .normal)
            }
        } else if pickerPhase == .WRITE_CHARACTERISTIC {
            if characteristicArray.count > tmpPickerIndex {
                selectedWriteCharacteristic = characteristicArray[tmpPickerIndex]
                Globals.shared.deviceBleWriteCharacteristicUuid = selectedWriteCharacteristic.uuid.uuidString
                debug("selected write characteristic \(selectedWriteCharacteristic.uuid)")
                // peripheral.discoverDescriptors(for: characteristics)
                btn_PickerDone.setTitle("select NOTIFY characteristic", for: .normal)
                pickerPhase = .READ_CHARACTERISTIC
                tmpPickerIndex = 0
                picker.selectRow(0, inComponent: 0, animated: false)
                picker.reloadAllComponents()
            }
        } else if pickerPhase == .READ_CHARACTERISTIC {
            if characteristicArray.count > tmpPickerIndex {
                pickerPhase = .PERIPHERAL
                selectedReadCharacteristic = characteristicArray[tmpPickerIndex]
                Globals.shared.deviceBleReadCharacteristicUuid = selectedReadCharacteristic.uuid.uuidString
                debug("selected notify characteristic \(selectedReadCharacteristic.uuid)")
                if selectedReadCharacteristic.properties.contains(.notify) {
                    for c in selectedService.characteristics! {
                        selectedPeripheral.blePeripheral.setNotifyValue(false, for: c)
                    }
                    selectedPeripheral.blePeripheral.setNotifyValue(true, for: selectedReadCharacteristic)
                    view.makeToast("ok")
                }
                // peripheral.discoverDescriptors(for: characteristics)
            }
            pickerView.alpha = 0
        }
    }

    // CODA

    func initQueue() {
        arraySequenze = []
    }

    func processQueue() {
        if queue.count == 0 {
            print("END")
            deviceIsInitialized = true
            return
        }

        if Globals.shared.deviceConnection == .BLE {
            writeBle(s: queue.first!)
        } else if Globals.shared.deviceConnection == .WIFI {
            writeWifi(s: queue.first!)
        } else {
            print("unknown connection type ???")
            return
        }

        if timeoutTimer != nil, timeoutTimer.isValid {
            timeoutTimer.invalidate()
        }
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { timer in
            print("queue timeout !!!")
            timer.invalidate()
            self.view.hideAllToasts()
            self.view.makeToast("TIMEOUT")
            return
        }
    }

    func continueQueue() {
        // next step, after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { // Change n to the desired number of seconds
            if self.queue.count > 0 {
                self.queue.remove(at: 0)
                self.processQueue()
            }
        }
    }

    @objc func received(notification: Notification) {
        if queue.count > 0 {
            if timeoutTimer != nil, timeoutTimer.isValid {
                timeoutTimer.invalidate()
                continueQueue()
            }
        } else if queue2.count > 0 {
            NotificationCenter.default.post(name: Notification.Name("received2"), object: notification.object)
        } else {
            let dic = notification.object as! [String: Any]
            let ss = dic["tag"] as! String
            debug("< '\(ss)' \(ss.count)")
        }
    }

    func startQueue2() {
        // TEST
        // if !deviceIsInitialized {
        // debug( "device not Initialized")
        // return
        // }
        // TEST
        indiceCmd = 0
        processQueue2()
    }

    func processQueue2() {
        if queue2.count == 0 {
            print("END queue2")
            return
        }

        let seq = queue2.first! as Sequence
        if indiceCmd >= seq.cmd.count {
            queue2.removeFirst()
            print("END cmd")
            startQueue2()
            return
        }
        let cmd = seq.cmd[indiceCmd]
        write(s: cmd)

        if timeoutTimer != nil, timeoutTimer.isValid {
            timeoutTimer.invalidate()
        }
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { timer in
            timer.invalidate()
            self.debug("queue2 timeout !!!")
            self.view.hideAllToasts()
            self.view.makeToast("TIMEOUT")
            return
        }
    }

    func continueQueue2() {
        // next step, after delay
        indiceCmd += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { // Change n to the desired number of seconds
            self.processQueue2()
        }
    }

    func debug(_ s: String) {
        print(s)
        DispatchQueue.main.async {
            self.tv.text += "\n\(s)"
            self.tv.scrollToBottom()
        }
    }

    @objc func received2(notification: Notification) {
        let dic = notification.object as! [String: Any]
        let reply = dic["tag"] as! String

        debug("< '\(reply)' \(reply.count)")

        // TEST
        var sid = ""
        let seq = queue2.first
        if dic["sid"] != nil {
            sid = dic["sid"] as! String
        } else {
            sid = (seq?.field.sid)!
        }
        // TEST

        let field = Fields.getInstance.getBySID(sid)

        if reply.contains("ERROR") {
            // do nothing
            debug("ERROR")
        } else if reply == "OK" {
            // do nothing
        } else if reply == "" {
            debug("empty")
        } else if field != nil {
            if Globals.shared.deviceType == .ELM327 {
                field?.strVal = decodeIsoTp(elmResponse2: reply) // ""
            } else {
                // http, cansee
                field?.strVal = reply
            }

//            print("\(field?.sid ?? "?") \(field?.name ?? "?")")
//            tv.text += "\n\(field?.sid ?? "?") \(field?.name ?? "?")"

            if field!.strVal.hasPrefix("7f") {
                debug("error 7f")
            } else if field!.strVal == "" {
                debug("empty")
            } else {
                let binString = getAsBinaryString(data: field!.strVal)
                debug(binString)
                onMessageCompleteEventField(binString_: binString, field: field!)

                if seq?.sidVirtual != nil {
                    var result = 0.0
                    switch seq?.sidVirtual {
                    case Sid.Instant_Consumption:
                        break
                    case Sid.FrictionTorque:
                        break
                    case Sid.DcPowerIn:
                        if fieldResult[Sid.TractionBatteryVoltage] != nil, fieldResult[Sid.TractionBatteryCurrent] != nil {
                            result = fieldResult[Sid.TractionBatteryVoltage]! * fieldResult[Sid.TractionBatteryCurrent]! / 1000.0
                        }
                    case Sid.DcPowerOut:
                        if fieldResult[Sid.TractionBatteryVoltage] != nil, fieldResult[Sid.TractionBatteryCurrent] != nil {
                            result = fieldResult[Sid.TractionBatteryVoltage]! * fieldResult[Sid.TractionBatteryCurrent]! / -1000.0
                        }
                    case Sid.ElecBrakeTorque:
                        break
                    case Sid.TotalPositiveTorque:
                        break
                    case Sid.TotalNegativeTorque:
                        break
                    case Sid.ACPilot:
                        break
                    default:
                        print("unknown virtual sid")
                    }
                    field?.value = result
                }

                if field!.isString() || field!.isHexString() {
                    debug("\(field!.strVal)")
                } else {
                    debug("\(field?.name ?? "?") \(String(format: "%.\(field!.decimals!)f", field!.getValue()))\n")
                    fieldResult[field!.sid] = field!.getValue()
                }
            }

        } else {
            debug("field \(seq?.field.sid ?? "?") not found")
        }

        if queue2.count > 0, timeoutTimer != nil, timeoutTimer.isValid {
            timeoutTimer.invalidate()
            continueQueue2()
        }
    }
}
