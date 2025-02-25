package com.threescreens.cordova.plugin.brotherprinter;

import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import java.io.File;
import java.io.FileWriter;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Set;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONException;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.preference.PreferenceManager;
import android.util.Base64;
import android.util.Log;

import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.app.PendingIntent;

import com.brother.ptouch.sdk.LabelInfo;
import com.brother.ptouch.sdk.NetPrinter;
import com.brother.ptouch.sdk.Printer;
import com.brother.ptouch.sdk.PrinterInfo;
import com.brother.ptouch.sdk.PrinterStatus;
import com.brother.ptouch.sdk.printdemo.common.MsgHandle;
import com.brother.ptouch.sdk.printdemo.printprocess.BasePrint;
import com.brother.ptouch.sdk.printdemo.printprocess.ImageBitmapPrint;
import com.brother.ptouch.sdk.printdemo.printprocess.ImageFilePrint;

import static com.threescreens.cordova.plugin.brotherprinter.PrinterInputParameterConstant.INCLUDE_BATTERY_STATUS;

import androidx.core.app.ActivityCompat;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class BrotherPrinter extends CordovaPlugin {
    //token to make it easy to grep logcat
    public static final String TAG = "BrotherPrinter";

    private static PrinterInfo.Model[] supportedModels = {
            PrinterInfo.Model.QL_810W,
            PrinterInfo.Model.QL_720NW,
            PrinterInfo.Model.QL_820NWB,
            PrinterInfo.Model.QL_1110NWB,
            PrinterInfo.Model.TD_2120N,
            PrinterInfo.Model.TD_2130N,
            PrinterInfo.Model.TD_2020,
            PrinterInfo.Model.TD_4550DNWB
    };

    private CallbackContext lastCallbackContext;
    private MsgHandle mHandle;
    private ImageBitmapPrint mBitmapPrint;
    private ImageFilePrint mFilePrint;

    private final static int PERMISSION_WRITE_EXTERNAL_STORAGE = 1;
    private static final int REQUEST_CODE_BLUETOOTH_PERMISSIONS = 1001; // Code de demande de permission

    private boolean isPermitWriteStorage() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (cordova.getActivity().checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    private boolean isBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

            if (cordova.getActivity().checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                    != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        } else {
            if (cordova.getActivity().checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        try {
            super.initialize(cordova, webView);
            mHandle = new MsgHandle(null);
            mBitmapPrint = new ImageBitmapPrint(cordova.getActivity(), mHandle);
            mFilePrint = new ImageFilePrint(cordova.getActivity(), mHandle);

            if (!isPermitWriteStorage()) {
                cordova.requestPermission(this, PERMISSION_WRITE_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE);
            }

        } catch (Throwable t) {
            LOG.e(TAG, "Failed to initialize label printer " + t);
        }
    }


    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        try {
            if ("findNetworkPrinters".equals(action)) {
                findNetworkPrinters(callbackContext);
                return true;
            }

            if ("findBluetoothPrinters".equals(action)) {
                findBluetoothPrinters(callbackContext);
                return true;
            }

            if ("findPrinters".equals(action)) {
                findPrinters(callbackContext);
                return true;
            }

            if ("setPrinter".equals(action)) {
                setPrinter(args, callbackContext);
                return true;
            }

            if ("printViaSDK".equals(action)) {
                printViaSDK(args, callbackContext);
                return true;
            }

            if ("sendUSBConfig".equals(action)) {
                sendUSBConfig(args, callbackContext);
                return true;
            }

        } catch (Throwable t) {
            sendError(callbackContext, t, "Failed while interacting with printer");
        }
        return false;
    }

    private class DiscoveredPrinter {
        public PrinterInfo.Model model;
        public PrinterInfo.Port port;
        public String modelName;
        public String serNo;
        public String ipAddress;
        public String macAddress;
        public String nodeName;
        public String location;
        public String paperLabelName;
        public String orientation;
        public String numberOfCopies;
        public String topMargin;
        public String leftMargin;
        public String includeBatteryStatus;
        public String customPaperFilePath;

        public DiscoveredPrinter(BluetoothDevice device) {
            port = PrinterInfo.Port.BLUETOOTH;
            ipAddress = null;
            serNo = null;
            nodeName = null;
            location = null;
            macAddress = device.getAddress();
            modelName = device.getName();

            String deviceName = device.getName();

            Log.e(TAG, "device name: " + deviceName);
            PrinterInfo.Model[] models = PrinterInfo.Model.values();
            for (PrinterInfo.Model model : models) {
                String modelName = model.toString().replaceAll("_", "-");
                if (deviceName.startsWith(modelName)) {
                    this.model = model;
                    break;
                }
            }
        }

        public DiscoveredPrinter(NetPrinter printer) {
            port = PrinterInfo.Port.NET;
            modelName = printer.modelName;
            ipAddress = printer.ipAddress;
            macAddress = printer.macAddress;
            nodeName = printer.nodeName;
            location = printer.location;

            PrinterInfo.Model[] models = PrinterInfo.Model.values();
            for (PrinterInfo.Model model : models) {
                String modelName = model.toString().replaceAll("_", "-");
                Log.i(TAG, "modelName : " + modelName);

                if (printer.modelName.endsWith(modelName)) {
                    Log.i(TAG, "model : " + model);

                    this.model = model;
                    break;
                }
            }
        }

        public DiscoveredPrinter(JSONObject object) throws JSONException {
            model = PrinterInfo.Model.valueOf(object.getString("model"));
            port = PrinterInfo.Port.valueOf(object.getString("port"));

            if (object.has("modelName")) {
                modelName = object.getString("modelName");
            }

            if (object.has("ipAddress")) {
                ipAddress = object.getString("ipAddress");
            }

            if (object.has("macAddress")) {
                macAddress = object.getString("macAddress");
            }

            if (object.has("serialNumber")) {
                serNo = object.getString("serialNumber");
            }

            if (object.has("nodeName")) {
                nodeName = object.getString("nodeName");
            }

            if (object.has("location")) {
                location = object.getString("location");
            }

            if (object.has("paperLabelName")) {
                paperLabelName = object.getString("paperLabelName");
            }

            if (object.has("orientation")) {
                orientation = object.getString("orientation");
            }

            if (object.has("numberOfCopies")) {
                numberOfCopies = object.getString("numberOfCopies");
            }

            if (object.has("topMargin")) {
                topMargin = object.getString("topMargin");
            }

            if (object.has("leftMargin")) {
                leftMargin = object.getString("leftMargin");
            }

            if (object.has("customPaperFilePath")) {
                customPaperFilePath = object.getString("customPaperFilePath");
            }

            if (object.has(INCLUDE_BATTERY_STATUS)) {
                includeBatteryStatus = object.getString(INCLUDE_BATTERY_STATUS);
            } else {
                includeBatteryStatus = Boolean.FALSE.toString();
            }

        }

        public JSONObject toJSON() throws JSONException {
            JSONObject result = new JSONObject();
            result.put("model", model.toString());
            result.put("port", port.toString());
            result.put("modelName", modelName);
            result.put("ipAddress", ipAddress);
            result.put("macAddress", macAddress);
            result.put("serialNumber", serNo);
            result.put("nodeName", nodeName);
            result.put("location", location);
            result.put("paperLabelName", paperLabelName);
            result.put("orientation", orientation);
            result.put("numberOfCopies", numberOfCopies);
            result.put("customPaperFilePath", customPaperFilePath);
            return result;
        }
    }

    private List<DiscoveredPrinter> enumerateNetPrinters() {
        ArrayList<DiscoveredPrinter> results = new ArrayList<DiscoveredPrinter>();

        try {
            Printer myPrinter = new Printer();
            PrinterInfo myPrinterInfo = new PrinterInfo();

            String[] models = new String[supportedModels.length];
            for (int i = 0; i < supportedModels.length; i++) {
                models[i] = supportedModels[i].toString().replaceAll("_", "-");
            }

            NetPrinter[] printers = myPrinter.getNetPrinters(models);
            for (int i = 0; i < printers.length; i++) {
                results.add(new DiscoveredPrinter(printers[i]));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return results;
    }

    private List<DiscoveredPrinter> enumerateBluetoothPrinters(final CallbackContext callbackctx) {
        ArrayList<DiscoveredPrinter> results = new ArrayList<>();
        try {
            BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if (bluetoothAdapter == null) {
                sendError(callbackctx, null, "No Bluetooth adapter found.");
                return results;
            }

            if (!bluetoothAdapter.isEnabled()) {
                sendError(callbackctx, null, "Bluetooth not enabled. Requesting enable.");

                Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                enableBtIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                cordova.getActivity().startActivity(enableBtIntent);
            }

            // Vérifier la permission BLUETOOTH_CONNECT pour Android 12 et supérieur
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Vérifier les permissions BLUETOOTH_CONNECT et BLUETOOTH_SCAN pour Android 12 et supérieur
                if (ActivityCompat.checkSelfPermission(cordova.getActivity(), Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED ||
                        ActivityCompat.checkSelfPermission(cordova.getActivity(), Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED ||
                        ActivityCompat.checkSelfPermission(cordova.getActivity(), Manifest.permission.BLUETOOTH_ADMIN) != PackageManager.PERMISSION_GRANTED

                ) {
                    Log.d(TAG, "REQUESTED PERMISSIONS");

                    // Demander les permissions
                    ActivityCompat.requestPermissions(cordova.getActivity(), new String[]{
                            Manifest.permission.BLUETOOTH_CONNECT,
                            Manifest.permission.BLUETOOTH_ADMIN,
                            Manifest.permission.BLUETOOTH_SCAN
                    }, 1001);

                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Log.d(TAG, "REQUEST PERMISSIONS 2");

                // Vérifier la permission ACCESS_FINE_LOCATION pour Android 10 et supérieur
                if (ActivityCompat.checkSelfPermission(cordova.getActivity(), Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    // Demander la permission
                    ActivityCompat.requestPermissions(cordova.getActivity(), new String[]{
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                    Manifest.permission.BLUETOOTH_ADMIN,
                                    Manifest.permission.BLUETOOTH_CONNECT
                            },
                            1001
                    );
                }
            }

            // Obtenir les appareils Bluetooth appairés
            Set<BluetoothDevice> pairedDevices = bluetoothAdapter.getBondedDevices();
            if (pairedDevices == null || pairedDevices.size() == 0) {
                sendError(callbackctx, null, "No paired Bluetooth devices found.");
                return results;
            }

            // Énumérer les appareils Bluetooth appairés
            for (BluetoothDevice device : pairedDevices) {

                if (device.getName() == null) {
                    continue;
                }

                DiscoveredPrinter printer = new DiscoveredPrinter(device);

                if (printer.model == null) {
                    continue;
                }

                results.add(printer);
            }
        } catch (Exception e) {
            sendError(callbackctx, e, "Error enumerating Bluetooth printers");
        }

        return results;
    }

    private void sendDiscoveredPrinters(final CallbackContext callbackctx, List<DiscoveredPrinter> discoveredPrinters) {
        JSONArray args = new JSONArray();

        for (DiscoveredPrinter p : discoveredPrinters) {
            try {
                args.put(p.toJSON());
            } catch (JSONException e) {
                // ignore this exception for now.
                e.printStackTrace();
            }
        }

        PluginResult result = new PluginResult(PluginResult.Status.OK, args);
        callbackctx.sendPluginResult(result);
    }

    private void findNetworkPrinters(final CallbackContext callbackctx) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    Log.d(TAG, "Début de la recherche des imprimantes réseau...");

                    List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
                    int maxAttempts = 3; // Nombre de tentatives
                    int waitTime = 2500; // Attente entre les tentatives (en ms)

                    for (int i = 0; i < maxAttempts; i++) {

                        // Exécuter la recherche
                        List<DiscoveredPrinter> newPrinters = enumerateNetPrinters();
                        discoveredPrinters.addAll(newPrinters);

                        // Si on a trouvé des imprimantes, on arrête la boucle
                        if (!newPrinters.isEmpty()) {
                            break;
                        }

                        Thread.sleep(waitTime);
                    }

                    // Envoi des résultats
                    if (!discoveredPrinters.isEmpty()) {
                        sendDiscoveredPrinters(callbackctx, discoveredPrinters);
                    } else {
                        Log.w(TAG, "Aucune imprimante trouvée après " + maxAttempts + " tentatives.");
                        throw new Exception("Aucune imprimante détectée");
                    }
                } catch (Throwable t) {
                    Log.e(TAG, "Erreur lors de la recherche des imprimantes réseau", t);
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, t.getMessage());
                    callbackctx.sendPluginResult(result);
                }
            }
        });
    }

    private void requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            cordova.requestPermissions(this, REQUEST_CODE_BLUETOOTH_PERMISSIONS, new String[]{
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
            });
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            cordova.requestPermissions(this, REQUEST_CODE_BLUETOOTH_PERMISSIONS, new String[]{
                    Manifest.permission.ACCESS_FINE_LOCATION
            });
        }
    }

    private void findBluetoothPrinters(final CallbackContext callbackctx) {
        lastCallbackContext = callbackctx; // ✅ Sauvegarde du callback

        if (!isBluetoothPermissions()) {
            Log.d(TAG, "Bluetooth permissions not granted. Requesting permissions 1.");
            requestBluetoothPermissions();
            Log.d(TAG, "Bluetooth permissions not granted. Requesting permissions.");
            return;
        }

        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                try {
                    List<DiscoveredPrinter> discoveredPrinters = enumerateBluetoothPrinters(callbackctx);
                    sendDiscoveredPrinters(callbackctx, discoveredPrinters);
                } catch (Throwable t) {
                    sendError(callbackctx, t, "Failed to find BlueTooth printers");
                }
            }
        });
    }

    private void findPrinters(final CallbackContext callbackctx) {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                try {
                    List<DiscoveredPrinter> allPrinters = enumerateNetPrinters();
                    allPrinters.addAll(enumerateBluetoothPrinters(callbackctx));
                    sendDiscoveredPrinters(callbackctx, allPrinters);
                } catch (Throwable t) {
                    sendError(callbackctx, t, "Failed to find printers");
                }
            }
        });
    }

    private void setPrinter(JSONArray args, final CallbackContext callbackctx) {
        try {

            JSONObject obj = args.getJSONObject(0);
            DiscoveredPrinter printer = new DiscoveredPrinter(obj);

            SharedPreferences sharedPreferences = PreferenceManager
                    .getDefaultSharedPreferences(cordova.getActivity());
            SharedPreferences.Editor editor = sharedPreferences.edit();

            editor.putString("printerModel", printer.model.toString());
            editor.putString("port", printer.port.toString());
            editor.putString("address", printer.ipAddress);
            editor.putString("macAddress", printer.macAddress);
            editor.putString("paperSize", printer.paperLabelName != null ? printer.paperLabelName : LabelInfo.QL700.W62.toString());
            editor.putString("orientation", printer.orientation != null ? printer.orientation : PrinterInfo.Orientation.LANDSCAPE.toString());
            editor.putString("numberOfCopies", printer.numberOfCopies);
            editor.putString("topMargin", printer.topMargin);
            editor.putString("leftMargin", printer.leftMargin);

            if (printer.customPaperFilePath != null && !printer.customPaperFilePath.isEmpty()) {
                String targetBinFolder = cordova.getActivity()
                        .getExternalFilesDir("customPaperFileSet/").toString();
                copyBinFile("public/" + printer.customPaperFilePath, targetBinFolder);
                editor.putString("customSetting", targetBinFolder + new File(printer.customPaperFilePath).getName());
            }

            editor.putString(INCLUDE_BATTERY_STATUS, printer.includeBatteryStatus);

            editor.commit();

            PluginResult result = new PluginResult(PluginResult.Status.OK, args);
            callbackctx.sendPluginResult(result);
        } catch (Throwable e) {
            sendError(callbackctx, e, "Failed to set the printer.");
        }
    }

    private void sendError(CallbackContext callbackctx, Throwable e, String s) {
        String errMessage = e == null ? "" : e.toString();
        Log.e(TAG, errMessage);
        PluginResult result = new PluginResult(PluginResult.Status.ERROR, s + " " + errMessage);
        callbackctx.sendPluginResult(result);
    }

    public Bitmap bmpFromBase64(String base64) {
        try {
            byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
            InputStream stream = new ByteArrayInputStream(bytes);

            return BitmapFactory.decodeStream(stream);
        } catch (Exception e) {
            Log.e(TAG, e + "");
            return null;
        }
    }


    private final ExecutorService printExecutor = Executors.newSingleThreadExecutor(); // Un seul thread pour les impressions


    private void printViaSDK(final JSONArray args, final CallbackContext callbackctx) {
        printExecutor.execute(() -> {
            try {
                /*PrinterInfo.ErrorCode errorCode = BasePrint.getmPrinter().getPrinterStatus().errorCode;

                if (errorCode != PrinterInfo.ErrorCode.ERROR_NONE){
                    Log.d(TAG, "Is bluethoot connecxion");

                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, "No printer has been set.");
                    callbackctx.sendPluginResult(result);
                    return;
                }*/

                // Récupérer les préférences de l'imprimante
                SharedPreferences sharedPreferences = PreferenceManager
                        .getDefaultSharedPreferences(cordova.getActivity());

                String port = sharedPreferences.getString("port", "");
                if ("".equals(port)) {
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, "No printer has been set.");
                    callbackctx.sendPluginResult(result);
                    return;
                }

                // Configurer Bluetooth si nécessaire
                if (PrinterInfo.Port.BLUETOOTH.toString().equals(port)) {

                    Log.d(TAG, "Is bluethoot connecxion");

                    BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
                    if (bluetoothAdapter == null) {
                        PluginResult result = new PluginResult(PluginResult.Status.ERROR, "This device does not have a bluetooth adapter.");
                        callbackctx.sendPluginResult(result);
                        return;
                    }

                    if (!bluetoothAdapter.isEnabled()) {
                        Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                        enableBtIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        cordova.getActivity().startActivity(enableBtIntent);
                    }

                    mBitmapPrint.setBluetoothAdapter(bluetoothAdapter);
                    mFilePrint.setBluetoothAdapter(bluetoothAdapter);
                }

                // Décoder l'image
                Bitmap bitmap = null;
                try {
                    String encodedImg = args.getString(0);
                    bitmap = bmpFromBase64(encodedImg);
                } catch (JSONException e) {
                    sendError(callbackctx, e, "An error occurred while trying to retrieve the image passed in.");
                    return;
                }

                if (bitmap == null) {
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, "The passed in data did not seem to be a decodable image. Please ensure it is a base64 encoded string of a supported Android format");
                    callbackctx.sendPluginResult(result);
                    return;
                }

                // Configurer et imprimer l'image
                mHandle.setCallbackContext(callbackctx);

                List<Bitmap> bitmaps = new ArrayList<>();
                bitmaps.add(bitmap);

                mBitmapPrint.setBitmaps(bitmaps);

                Thread printThread = mBitmapPrint.print();

                printThread.join();

                if (mBitmapPrint.getException() != null) {
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, mBitmapPrint.getException().getMessage());
                    callbackctx.sendPluginResult(result);
                    return;
                }

                callbackctx.success("Printing completed successfully.");

            } catch (Throwable t) {
                sendError(callbackctx, t, "Failed to printViaSDK ");
            } finally {
                mHandle.setCallbackContext(null);
                mBitmapPrint.setBitmaps(null);
            }
        });
    }

    private void sendUSBConfig(final JSONArray args, final CallbackContext callbackctx) {

        cordova.getThreadPool().execute(new Runnable() {
            public void run() {

                Printer myPrinter = new Printer();

                Context context = cordova.getActivity().getApplicationContext();

                UsbManager usbManager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
                UsbDevice usbDevice = myPrinter.getUsbDevice(usbManager);
                if (usbDevice == null) {
                    Log.d(TAG, "USB device not found");
                    return;
                }

                final String ACTION_USB_PERMISSION = "com.threescreens.cordova.plugin.brotherprinter.USB_PERMISSION";

                PendingIntent permissionIntent = PendingIntent.getBroadcast(context, 0, new Intent(ACTION_USB_PERMISSION), 0);
                usbManager.requestPermission(usbDevice, permissionIntent);

                final BroadcastReceiver mUsbReceiver = new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context context, Intent intent) {
                        String action = intent.getAction();
                        if (ACTION_USB_PERMISSION.equals(action)) {
                            synchronized (this) {
                                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
                                    Log.d(TAG, "USB permission granted");
                                else
                                    Log.d(TAG, "USB permission rejected");
                            }
                        }
                    }
                };

                context.registerReceiver(mUsbReceiver, new IntentFilter(ACTION_USB_PERMISSION));

                while (true) {
                    if (!usbManager.hasPermission(usbDevice)) {
                        usbManager.requestPermission(usbDevice, permissionIntent);
                    } else {
                        break;
                    }

                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }

                PrinterInfo myPrinterInfo = new PrinterInfo();

                myPrinterInfo = myPrinter.getPrinterInfo();

                myPrinterInfo.printerModel = PrinterInfo.Model.QL_720NW;
                myPrinterInfo.port = PrinterInfo.Port.USB;
                myPrinterInfo.paperSize = PrinterInfo.PaperSize.CUSTOM;

                myPrinter.setPrinterInfo(myPrinterInfo);

                LabelInfo myLabelInfo = new LabelInfo();

                myLabelInfo.labelNameIndex = myPrinter.checkLabelInPrinter();
                myLabelInfo.isAutoCut = true;
                myLabelInfo.isEndCut = true;
                myLabelInfo.isHalfCut = false;
                myLabelInfo.isSpecialTape = false;

                //label info must be set after setPrinterInfo, it's not in the docs
                myPrinter.setLabelInfo(myLabelInfo);

                try {
                    File outputDir = context.getCacheDir();
                    File outputFile = new File(outputDir.getPath() + "configure.prn");

                    FileWriter writer = new FileWriter(outputFile);
                    writer.write(args.optString(0, null));
                    writer.close();

                    PrinterStatus status = myPrinter.printFile(outputFile.toString());
                    outputFile.delete();

                    String status_code = "" + status.errorCode;

                    Log.d(TAG, "PrinterStatus: " + status_code);

                    PluginResult result;
                    result = new PluginResult(PluginResult.Status.OK, status_code);
                    callbackctx.sendPluginResult(result);

                } catch (IOException e) {
                    Log.d(TAG, "Temp file action failed: " + e.toString());
                }
            }
        });
    }

    private void copyBinFile(String filename, String targetPath) {
        AssetManager assetManager = cordova.getActivity().getAssets();
        InputStream in = null;
        OutputStream out = null;
        String newFileName = null;
        try {
            in = assetManager.open(filename);

            newFileName = targetPath + filename.substring(filename.lastIndexOf("/") + 1);

            out = new FileOutputStream(newFileName);

            byte[] buffer = new byte[1024];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            in.close();
            in = null;
            out.flush();
            out.close();
            out = null;
            Log.i("Brother/SDKEvent", "file copied :" + filename);

        } catch (Exception e) {
            Log.e("Brother/SDKEvent", "Exception in copyBinFile() " + e.toString());
        }

    }

}
