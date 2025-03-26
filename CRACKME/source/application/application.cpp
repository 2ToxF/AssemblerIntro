#include <gst/gst.h>
#include <gtk/gtk.h>

#include "application.h"
#include "errors.h"

const int           DEFAULT_WINDOW_WIDTH    = 1200;
const int           DEFAULT_WINDOW_HEIGHT   = 600;

const char* const   APPLICATION_NAME        = "CRACKME";
const char* const   CSS_PATH                = "CSS/style.css";

const char* const   WINDOW_TITLE            = "Crack FREE";

static void LoadCSS     ();
static void RunWindow   (GtkApplication* app, gpointer* user_data);

static GtkWidget* CreateWindow  (GtkApplication* app);
static GtkWidget* CreateOverlay (GtkWidget* window);


int CrackmeApplication(const char file_to_crack_name[], int* argcp, char** argvp[])
{
    gst_init(argcp, argvp);

    GtkApplication* app = gtk_application_new(APPLICATION_NAME, G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(RunWindow), NULL);

    int app_status = g_application_run(G_APPLICATION(app), *argcp, *argvp);

    g_object_unref(app);
    gst_deinit();

    return app_status;
}


// =================================================
// =================================================
//                  Main functions
// =================================================
// =================================================

static void LoadCSS()
{
    GtkCssProvider* css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_path(css_provider, CSS_PATH);

    GdkScreen* screen = gdk_screen_get_default();
    gtk_style_context_add_provider_for_screen(screen, GTK_STYLE_PROVIDER(css_provider), GTK_STYLE_PROVIDER_PRIORITY_USER);
    // TODO: CHECK !!!!!!!!!
}


static void Window(GtkApplication* app, gpointer* user_data)
{
    LoadCSS();

    GtkWidget* window       = CreateWelcomeWindow(app);
    GtkWidget* overlay      = CreateWelcomeOverlay(window);
    GtkWidget* background   = CreateWelcomeBackground(overlay);
    GtkWidget* box          = CreateWelcomeBox(overlay);
    GtkWidget* label        = CreateWelcomeLabel(label);
    GtkWidget* button       = CreateWelcomeButton(box);

    gtk_window_present(GTK_WINDOW(window));
}


// =================================================
// =================================================
//             Welcome Window functions
// =================================================
// =================================================

static GtkWidget* CreateWindow(GtkApplication* app)
{
    GtkWidget* window = gtk_application_window_new();

    gtk_window_set_title        (GTK_WINDOW(window), WINDOW_TITLE);
    gtk_window_set_default_size (GTK_WINDOW(window), DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
    gtk_window_set_resizable    (GTK_WINDOW(window), FALSE);

    return window;
}


static GtkWidget* CreateOverlay(GtkWidget* window)
{
    GtkWidget* overlay = gtk_overlay_new();
    gtk_window_set_child(GTK_WINDOW(window), overlay);
    return overlay;
}


static GtkWidget* CreateBackground(GtkWidget* overlay)
{
    GtkWidget* background = gtk_picture_new_for_filename();
    gtk_overlay_set_child(GTK_OVERLAY(overlay), background);
    gtk_picture_set_content_fit(GTK_PICTURE(background), GTK_CONTENT_FIT_COVER);
    return background;
}
