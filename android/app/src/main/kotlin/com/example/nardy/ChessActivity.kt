package com.example.nardy

import android.app.Activity
import android.os.Bundle
import android.graphics.Color
import android.widget.Button
import android.widget.LinearLayout
import app.chess2.embed.Chess2View

class ChessActivity : Activity() {
    private lateinit var chess: Chess2View
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(Color.rgb(16,28,27)) }
        val back = Button(this).apply { text = "‹ Все игры"; setOnClickListener { finish() } }
        root.addView(back, LinearLayout.LayoutParams(-1, -2))
        chess = Chess2View(this)
        root.addView(chess, LinearLayout.LayoutParams(-1, 0, 1f))
        root.setOnApplyWindowInsetsListener { view, insets ->
            view.setPadding(insets.systemWindowInsetLeft,insets.systemWindowInsetTop,insets.systemWindowInsetRight,insets.systemWindowInsetBottom)
            insets
        }
        setContentView(root)
        val origin = intent.getStringExtra("club_origin")
        val ticket = intent.getStringExtra("club_ticket")
        chess.setClubOrigin(origin)
        if (!chess.restoreGameState(savedInstanceState?.getBundle("chess"))) {
            if (origin != null && ticket != null) chess.openClubGame(ticket)
            else chess.openLocalGame()
        }
    }
    override fun onSaveInstanceState(outState: Bundle) {
        val saved=Bundle(); chess.saveGameState(saved);outState.putBundle("chess",saved)
        super.onSaveInstanceState(outState)
    }
    override fun onResume() {super.onResume();if(::chess.isInitialized)chess.onHostResume()}
    override fun onPause() {if(::chess.isInitialized)chess.onHostPause();super.onPause()}
    override fun onDestroy() {if(::chess.isInitialized)chess.release();super.onDestroy()}
    @Deprecated("Legacy back callback")
    override fun onBackPressed() {if(!chess.goBack()) super.onBackPressed()}
}
