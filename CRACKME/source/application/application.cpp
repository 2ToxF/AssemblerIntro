#include <gtk/gtk.h>

#include "application.h"
#include "patcher.h"

const int           BOX_ELEMENT_SPACING     = 10;
const int           BOX_MARGIN_LEFT_SIDE    = 20;
const int           DEFAULT_WINDOW_WIDTH    = 1200;
const int           DEFAULT_WINDOW_HEIGHT   = 600;
const int           UPDATE_ANIMATION_PERIOD = 10;

const char* const   APPLICATION_NAME        = "Crack.ME";
const char* const   BUTTON_NAME             = "button";
const char* const   CSS_PATH                = "CSS/style.css";
const char* const   DEFAULT_LABEL_TEXT      = "Please enter path to file you want to crack...";
const char* const   ENTRY_FIELD_NAME        = "entry_field";
const char* const   GIF_PATH                = "Widgets/background.gif";
const char* const   LABEL_NAME              = "label";
const char* const   SUCCESS_CRACK_MSG       = "SUCCESS! Now you can write any password there!";
const char* const   UNKNOWN_FILE_NAME_MSG   = " Sorry, I don't have cracks for this file yet ";
const char* const   WINDOW_TITLE            = "Crack.ME";

struct AnimationData{
    GtkPicture* picture;
    GdkPixbufAnimation* animation;
    GdkPixbufAnimationIter* iter;
    guint timeout_id;
};

static void         CrackFile       (GtkButton*, gpointer* user_data);
static void         LoadCSS         ();
static void         RunWindow       (GtkApplication* app, gpointer*);

static GtkWidget*   CreateBox       (GtkWidget* overlay);
static GtkWidget*   CreateButton    (GtkWidget* box);
static GtkWidget*   CreateEntryField(GtkWidget* box);
static GtkWidget*   CreateGif       (GtkWidget* overlay);
static GtkWidget*   CreateLabel     (GtkWidget* box);
static GtkWidget*   CreateOverlay   (GtkWidget* window);
static GtkWidget*   CreateWindow    (GtkApplication* app);
static gboolean     UpdateAnimation (gpointer user_data);


int CrackmeApplication(int* argcp, char** argvp[])
{
    GtkApplication* app = gtk_application_new(APPLICATION_NAME, G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(RunWindow), NULL);

    int app_status = g_application_run(G_APPLICATION(app), *argcp, *argvp);

    g_object_unref(app);

    return app_status;
}


// =================================================
// =================================================
//                  Main functions
// =================================================
// =================================================

static void CrackFile(GtkButton*, gpointer* user_data)
{
    GtkBox* box = GTK_BOX(user_data);

    GtkWidget* label       = gtk_widget_get_first_child(GTK_WIDGET(box));
    GtkWidget* entry_field = gtk_widget_get_next_sibling(label);

    GtkEntryBuffer* file_name_buffer = gtk_entry_get_buffer(GTK_ENTRY(entry_field));
    const char* file_path = gtk_entry_buffer_get_text(file_name_buffer);

    PatchResultType patch_res = FilePatch(file_path);
    if (patch_res == UNKNOWN_FILE_NAME)
        gtk_label_set_label(GTK_LABEL(label), UNKNOWN_FILE_NAME_MSG);

    else
        gtk_label_set_label(GTK_LABEL(label), SUCCESS_CRACK_MSG);
}


static void LoadCSS()
{
    GtkCssProvider* css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_path(css_provider, CSS_PATH);

    GdkDisplay* display = gdk_display_get_default();
    gtk_style_context_add_provider_for_display(display, GTK_STYLE_PROVIDER(css_provider), GTK_STYLE_PROVIDER_PRIORITY_USER);
}


static void RunWindow(GtkApplication* app, gpointer*)
{
    LoadCSS();

    GtkWidget* window       = CreateWindow(app);
    GtkWidget* overlay      = CreateOverlay(window);
                              CreateGif(overlay);

    GtkWidget* box          = CreateBox(overlay);
                              CreateLabel(box);
                              CreateEntryField(box);
    GtkWidget* button       = CreateButton(box);

    g_signal_connect(button, "clicked", G_CALLBACK(CrackFile), box);

    gtk_window_present(GTK_WINDOW(window));
}


// =================================================
// =================================================
//              Window build functions
// =================================================
// =================================================

static GtkWidget* CreateBox(GtkWidget* overlay)
{
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, BOX_ELEMENT_SPACING);

    gtk_widget_set_margin_start (box, BOX_MARGIN_LEFT_SIDE);
    gtk_widget_set_halign       (box, GTK_ALIGN_START);
    gtk_widget_set_valign       (box, GTK_ALIGN_CENTER);

    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), box);

    return box;
}


static GtkWidget* CreateButton(GtkWidget* box)
{
    GtkWidget* crack_button = gtk_button_new_with_label("Crack this!");

    gtk_widget_set_name(crack_button, BUTTON_NAME);
    gtk_box_append(GTK_BOX(box), crack_button);

    return crack_button;
}


static GtkWidget* CreateEntryField(GtkWidget* box)
{
    GtkWidget* entry_field = gtk_entry_new();

    gtk_widget_set_name(entry_field, ENTRY_FIELD_NAME);
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry_field), "/path/to/file");
    gtk_box_append(GTK_BOX(box), entry_field);

    return entry_field;
}


static GtkWidget* CreateGif(GtkWidget* overlay)
{
    GtkWidget* picture = gtk_picture_new();

    GError* error = NULL;
    GdkPixbufAnimation* animation = gdk_pixbuf_animation_new_from_file(GIF_PATH, &error);

    GdkPixbufAnimationIter* iter = gdk_pixbuf_animation_get_iter(animation, NULL);
    AnimationData* data = g_new0(AnimationData, 1);

    data->picture   = GTK_PICTURE(picture);
    data->animation = animation;
    data->iter      = iter;

    g_timeout_add(UPDATE_ANIMATION_PERIOD, UpdateAnimation, data);

    gtk_overlay_add_overlay    (GTK_OVERLAY(overlay), picture);
    gtk_picture_set_content_fit(GTK_PICTURE(picture), GTK_CONTENT_FIT_COVER);

    return picture;
}


static GtkWidget* CreateLabel(GtkWidget* box)
{
    GtkWidget* label = gtk_label_new(NULL);

    gtk_widget_set_name(label, LABEL_NAME);
    gtk_label_set_label(GTK_LABEL(label), DEFAULT_LABEL_TEXT);
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    gtk_box_append(GTK_BOX(box), label);

    return label;
}


static GtkWidget* CreateOverlay(GtkWidget* window)
{
    GtkWidget* overlay = gtk_overlay_new();
    gtk_window_set_child(GTK_WINDOW(window), overlay);
    return overlay;
}


static GtkWidget* CreateWindow(GtkApplication* app)
{
    GtkWidget* window = gtk_application_window_new(app);

    gtk_window_set_title        (GTK_WINDOW(window), WINDOW_TITLE);
    gtk_window_set_default_size (GTK_WINDOW(window), DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
    gtk_window_set_resizable    (GTK_WINDOW(window), FALSE);

    return window;
}


static gboolean UpdateAnimation(gpointer user_data)
{
    AnimationData* data = (AnimationData*)user_data;

    gdk_pixbuf_animation_iter_advance(data->iter, NULL);
    GdkPixbuf* frame = gdk_pixbuf_animation_iter_get_pixbuf(data->iter);
    GdkPaintable* paintable = GDK_PAINTABLE(gdk_texture_new_for_pixbuf(frame));
    gtk_picture_set_paintable(data->picture, paintable);

    return TRUE;
}
