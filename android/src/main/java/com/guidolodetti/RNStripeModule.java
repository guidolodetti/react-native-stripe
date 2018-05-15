
package com.guidolodetti;

import android.content.Intent;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.Log;
import android.widget.Toast;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.stripe.android.CustomerSession;
import com.stripe.android.EphemeralKeyProvider;
import com.stripe.android.EphemeralKeyUpdateListener;
import com.stripe.android.PaymentConfiguration;
import com.stripe.android.PaymentSession;
import com.stripe.android.view.PaymentMethodsActivity;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import static com.facebook.react.bridge.ReadableType.Array;
import static com.facebook.react.bridge.ReadableType.Map;

public class RNStripeModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;
    private EphemeralKeyUpdateListener keyUpdateListener;

    public RNStripeModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    @Override
    public String getName() {
        return "RNStripe";
    }


    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    @ReactMethod
    public void initPaymentContext(ReadableMap options) {
        PaymentConfiguration.init(options.getString("publishableKey"));
        CustomerSession.initCustomerSession(new EphemeralKeyProvider() {
            @Override
            public void createEphemeralKey(@NonNull String apiVersion,
                                           @NonNull EphemeralKeyUpdateListener _keyUpdateListener) {
                Log.e("RNStripe", "Init");
                keyUpdateListener = _keyUpdateListener;
                WritableMap params = Arguments.createMap();
                params.putString("apiVersion", apiVersion);
                sendEvent(getReactApplicationContext(),
                        "RNStripeRequestedCustomerKey", params);
            }
        });
    }

    @ReactMethod
    public void retrievedCustomerKey(ReadableMap customerKey) {
        try {
            JSONObject customerKeyJson = convertMapToJson(customerKey);
            Log.e("RNStripe", "Stripe customer key: "+customerKeyJson.toString());
            if (keyUpdateListener != null) {
                keyUpdateListener.onKeyUpdate(customerKeyJson.toString());
            }
        } catch (JSONException e) {
            Log.e("RNStripe", "JSON Convertion error");
        }
    }

    @ReactMethod
    public void presentPaymentMethodsViewController(Promise promise) {
        Intent payIntent = PaymentMethodsActivity.newIntent(getReactApplicationContext());
        getReactApplicationContext().startActivity(payIntent);
    }

    private static JSONObject convertMapToJson(ReadableMap readableMap) throws JSONException {
        JSONObject object = new JSONObject();
        ReadableMapKeySetIterator iterator = readableMap.keySetIterator();
        while (iterator.hasNextKey()) {
            String key = iterator.nextKey();
            switch (readableMap.getType(key)) {
                case Null:
                    object.put(key, JSONObject.NULL);
                    break;
                case Boolean:
                    object.put(key, readableMap.getBoolean(key));
                    break;
                case Number:
                    object.put(key, readableMap.getDouble(key));
                    break;
                case String:
                    object.put(key, readableMap.getString(key));
                    break;
                case Map:
                    object.put(key, convertMapToJson(readableMap.getMap(key)));
                    break;
                case Array:
                    object.put(key, convertArrayToJson(readableMap.getArray(key)));
                    break;
            }
        }
        return object;
    }

    private static JSONArray convertArrayToJson(ReadableArray readableArray) throws JSONException {
        JSONArray array = new JSONArray();
        for (int i = 0; i < readableArray.size(); i++) {
            switch (readableArray.getType(i)) {
                case Null:
                    break;
                case Boolean:
                    array.put(readableArray.getBoolean(i));
                    break;
                case Number:
                    array.put(readableArray.getDouble(i));
                    break;
                case String:
                    array.put(readableArray.getString(i));
                    break;
                case Map:
                    array.put(convertMapToJson(readableArray.getMap(i)));
                    break;
                case Array:
                    array.put(convertArrayToJson(readableArray.getArray(i)));
                    break;
            }
        }
        return array;
    }
}
