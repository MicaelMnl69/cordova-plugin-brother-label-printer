/**
 * ImagePrint for printing
 *
 * @author Brother Industries, Ltd.
 * @version 2.2
 */
package com.brother.ptouch.sdk.printdemo.printprocess;

import static com.threescreens.cordova.plugin.brotherprinter.BrotherPrinter.TAG;

import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;

import com.brother.ptouch.sdk.PrinterInfo.ErrorCode;
import com.brother.ptouch.sdk.printdemo.common.MsgHandle;

import java.util.List;

public class ImageBitmapPrint extends BasePrint {

    private List<Bitmap> mBitmaps;

    public ImageBitmapPrint(Context context, MsgHandle mHandle) {
        super(context, mHandle);
    }

    /**
     * set print data
     */
    public List<Bitmap> getBitmaps() {
        return mBitmaps;
    }

    /**
     * set print data
     */
    public void setBitmaps(List<Bitmap> bitmaps) {
        mBitmaps = bitmaps;
    }

    /**
     * do the particular print
     */
    @Override
    protected void doPrint() {

        if (mBitmaps == null) {
            Log.e(TAG, "La liste des bitmaps est null ou vide.");
            return;
        }
        int count = mBitmaps.size();

        for (int i = 0; i < count; i++) {

            Bitmap bitmap = mBitmaps.get(i);

            mPrintResult = mPrinter.printImage(bitmap);

            // if error, stop print next files
            if (mPrintResult.errorCode != ErrorCode.ERROR_NONE) {
                break;
            }
        }
    }
}
