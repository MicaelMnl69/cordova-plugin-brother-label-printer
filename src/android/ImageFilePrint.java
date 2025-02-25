/**
 * FilePrint for printing
 *
 * @author Brother Industries, Ltd.
 * @version 2.2
 */
package com.brother.ptouch.sdk.printdemo.printprocess;

import static com.threescreens.cordova.plugin.brotherprinter.BrotherPrinter.TAG;

import android.content.Context;
import android.util.Log;

import com.brother.ptouch.sdk.PrinterInfo.ErrorCode;
import com.brother.ptouch.sdk.printdemo.common.MsgHandle;

import java.util.ArrayList;

public class ImageFilePrint extends BasePrint {

    private ArrayList<String> mImageFiles;

    public ImageFilePrint(Context context, MsgHandle mHandle) {
        super(context, mHandle);
    }

    /**
     * set print data
     */
    public ArrayList<String> getFiles() {
        return mImageFiles;
    }

    /**
     * set print data
     */
    public void setFiles(ArrayList<String> files) {
        mImageFiles = files;
    }

    /**
     * do the particular print
     */
    @Override
    protected void doPrint() {

        if (mImageFiles == null) {
            Log.e(TAG, "La liste des bitmaps est null ou vide.");
            return;
        }

        int count = mImageFiles.size();

        for (int i = 0; i < count; i++) {

            String strFile = mImageFiles.get(i);

            mPrintResult = mPrinter.printFile(strFile);

            // if error, stop print next files
            if (mPrintResult.errorCode != ErrorCode.ERROR_NONE) {
                break;
            }
        }
    }
}
