package app.chess2.embed;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.util.AttributeSet;
import android.view.Gravity;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import org.json.JSONException;
import org.json.JSONTokener;

import java.util.regex.Pattern;

/** Embeds the published Chess 2 game in an Android screen. Call from the main thread. */
public final class Chess2View extends FrameLayout {
    public static final String HOME = "https://chess-2-smoke-and-jokers.purpledaffodil32.chatgpt.site/";
    private static final String LOCAL = "file:///android_asset/flutter_assets/assets/chess2/index.html";
    private static final String HOST = Uri.parse(HOME).getHost();
    private static final Pattern ROOM_ID = Pattern.compile("[0-9a-f]{24}");

    private final WebView game;
    private final ProgressBar loading;
    private final LinearLayout errorView;
    private Uri requestedPage = Uri.parse(HOME);
    private boolean pageFailed;
    private boolean released;

    public Chess2View(Context context) {
        this(context, null);
    }

    public Chess2View(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public Chess2View(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);

        int background = Color.rgb(16, 28, 27);
        game = new WebView(context);
        game.setBackgroundColor(background);
        WebSettings settings = game.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setUseWideViewPort(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportMultipleWindows(false);
        game.setWebViewClient(new GameClient());
        addView(game, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

        loading = new ProgressBar(context);
        loading.setContentDescription("Загрузка «Шахмат 2»");
        loading.setVisibility(GONE);
        addView(loading, new LayoutParams(dp(42), dp(42), Gravity.CENTER));

        errorView = new LinearLayout(context);
        errorView.setOrientation(LinearLayout.VERTICAL);
        errorView.setGravity(Gravity.CENTER);
        errorView.setPadding(dp(24), dp(24), dp(24), dp(24));
        errorView.setBackgroundColor(background);

        TextView message = new TextView(context);
        message.setText("Не удалось загрузить «Шахматы 2»");
        message.setTextSize(16);
        message.setTextColor(Color.WHITE);
        message.setGravity(Gravity.CENTER);
        errorView.addView(message);
        Button retry = new Button(context);
        retry.setText("Повторить");
        retry.setOnClickListener(v -> load(requestedPage));
        errorView.addView(retry);
        errorView.setVisibility(GONE);
        addView(errorView, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    public void openLocalGame() {
        load(Uri.parse(LOCAL));
    }

    private Uri clubOrigin;

    public void setClubOrigin(String base) {
        Uri uri = parse(base);
        if (uri != null && "https".equals(uri.getScheme()) && uri.getHost() != null
                && uri.getUserInfo() == null) {
            clubOrigin = uri;
        }
    }

    public void openClubGame(String ticket) {
        if (clubOrigin == null || !ticket.matches("[a-f0-9]{64}")) {
            openLocalGame();
            return;
        }
        requestedPage = clubOrigin.buildUpon().path("/assets/assets/chess2/index.html").build();
        showLoading();
        game.postUrl(clubOrigin.buildUpon().path("/chess-entry").build().toString(),
            ("ticket=" + ticket).getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private boolean isSupportedPage(Uri uri) {
        if (uri == null) return false;
        if (LOCAL.equals(uri.toString()) || isGamePage(uri)) return true;
        return clubOrigin != null && "https".equals(uri.getScheme())
            && clubOrigin.getEncodedAuthority().equals(uri.getEncodedAuthority())
            && ("/chess-entry".equals(uri.getPath())
                || "/assets/assets/chess2/index.html".equals(uri.getPath()));
    }

    /** Opens the lobby. Existing logins in the host app's WebView storage are kept. */
    public void openGame() {
        load(Uri.parse(HOME));
    }

    /** Opens a Chess 2 room or invite. Returns false for an invalid link. */
    public boolean openRoom(Uri uri) {
        if (released || !isRoom(uri)) return false;
        load(uri);
        return true;
    }

    public boolean goBack() {
        if (released || !game.canGoBack()) return false;
        game.goBack();
        return true;
    }

    /** Reads the game's current invite, if the lobby is showing one. */
    public void readInvitation(InvitationCallback callback) {
        if (callback == null) throw new IllegalArgumentException("callback is required");
        if (released || !isGamePage(parse(game.getUrl()))) {
            callback.onInvitation(null);
            return;
        }
        // Only read an invite the game currently makes available to its host.
        game.evaluateJavascript(
            "(function(){var p=document.getElementById('invite-panel'),"
                + "e=document.getElementById('invite-link');"
                + "return p&&!p.hidden&&e?e.value:null;})()",
            json -> callback.onInvitation(released ? null : invitationFromResult(json))
        );
    }

    public void saveGameState(Bundle outState) {
        if (released) return;
        Uri current = pageFailed ? requestedPage : parse(game.getUrl());
        outState.putString("page", isSupportedPage(current) ? current.toString() : requestedPage.toString());
    }

    /** Call on a new view before openGame. Returns false if there was no saved screen. */
    public boolean restoreGameState(Bundle state) {
        if (released || state == null) return false;
        Uri lastPage = parse(state.getString("page"));
        if (!isSupportedPage(lastPage)) return false;
        load(lastPage);
        return true;
    }

    public void onHostPause() {
        if (!released) game.onPause();
    }

    public void onHostResume() {
        if (!released) game.onResume();
    }

    /** Call when the host destroys this view. */
    public void release() {
        if (released) return;
        released = true;
        game.stopLoading();
        removeView(game);
        game.destroy();
    }

    public interface InvitationCallback {
        /** The link, or null when the current room has no visible invitation. */
        void onInvitation(Uri invitation);
    }

    private void load(Uri uri) {
        if (released) return;
        requestedPage = uri;
        showLoading();
        game.loadUrl(uri.toString());
    }

    private void showLoading() {
        pageFailed = false;
        errorView.setVisibility(GONE);
        loading.setVisibility(VISIBLE);
    }

    private void showError() {
        pageFailed = true;
        loading.setVisibility(GONE);
        errorView.setVisibility(VISIBLE);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static Uri parse(String value) {
        return value == null ? null : Uri.parse(value);
    }

    private static boolean isGamePage(Uri uri) {
        if (uri == null || !"https".equalsIgnoreCase(uri.getScheme())) return false;
        String authority = uri.getEncodedAuthority();
        if (!HOST.equalsIgnoreCase(authority) && !(HOST + ":443").equalsIgnoreCase(authority)) return false;
        String path = uri.getEncodedPath();
        return path == null || path.isEmpty() || "/".equals(path);
    }

    private static boolean isRoom(Uri uri) {
        if (!isGamePage(uri)) return false;
        String room = uri.getQueryParameter("room");
        return room != null && ROOM_ID.matcher(room).matches();
    }

    private static Uri invitationFromResult(String json) {
        if (json == null) return null;
        try {
            Object value = new JSONTokener(json).nextValue();
            Uri uri = value instanceof String ? parse((String) value) : null;
            return isRoom(uri) && uri.getEncodedFragment() != null ? uri : null;
        } catch (JSONException ignored) {
            return null;
        }
    }

    private final class GameClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return request.isForMainFrame() && !isSupportedPage(request.getUrl());
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            if (released) return;
            Uri page = parse(url);
            if (!isSupportedPage(page)) {
                view.stopLoading();
                showError();
                return;
            }
            if (!"/chess-entry".equals(page.getPath())) requestedPage = page;
            showLoading();
        }

        @Override
        public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
            Uri page = parse(url);
            if (!released && isSupportedPage(page)) requestedPage = page;
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            if (released || pageFailed || !isSupportedPage(parse(url))) return;
            loading.setVisibility(GONE);
            if (isGamePage(parse(view.getUrl()))) {
                try (java.io.InputStream script = getContext().getAssets()
                        .open("flutter_assets/assets/chess2/drag.js")) {
                    java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
                    byte[] buffer = new byte[4096];
                    int count;
                    while ((count = script.read(buffer)) != -1) bytes.write(buffer, 0, count);
                    view.evaluateJavascript("if (typeof board !== 'undefined') {"
                        + bytes.toString("UTF-8") + "\n}", null);
                } catch (java.io.IOException error) {
                    android.util.Log.w("Chess2View", "Chess drag script unavailable", error);
                }
            }
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (!released && request.isForMainFrame()) showError();
        }

        @Override
        public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse error) {
            if (!released && request.isForMainFrame()) showError();
        }
    }
}
