#include "ruby.h"
#include "db.h"
#include "player.h"

static VALUE tinymud_module;
static VALUE player_class;

/******************************************************************************/
/* The following are "stubbed" out from interface.h/.c I they touch underlying*/
/* socket/networking stuff, for now I don't want this to get in the way      */
/******************************************************************************/

void notify(dbref player_ref, const char *msg)
{
  ID method = rb_intern("do_notify");
  VALUE player = INT2FIX(player_ref);
  VALUE message = rb_str_new2(msg);
  rb_funcall(tinymud_module, method, player, message);
}

void emergency_shutdown(void)
{
  ID method = rb_intern("do_emergency_shutdown");
  rb_funcall(tinymud_module, method, 0);
}

/* These are defined in ruby and called from the above - To allow mocking in ruby */

static VALUE do_notify(VALUE self, VALUE player, VALUE message)
{
  (void) self;
  (void) player;
  (void) message;
  return Qnil;
}

static VALUE do_emergency_shutdown(VALUE self)
{
  (void) self;
  return Qnil;
}

/******************************************************************************/

static VALUE do_lookup_player(VALUE self, VALUE player_name)
{
    (void) self;
    const char* name = STR2CSTR(player_name);
    dbref ref = lookup_player(name);
    return INT2FIX(ref);
}

static VALUE do_connect_player(VALUE self, VALUE player_name, VALUE password)
{
    (void) self;
    const char* name = STR2CSTR(player_name);
    const char* pwd = STR2CSTR(password);
    dbref ref = connect_player(name, pwd);
    return INT2FIX(ref);
}

static VALUE do_create_player(VALUE self, VALUE player_name, VALUE password)
{
    (void) self;
    const char* name = STR2CSTR(player_name);
    const char* pwd = STR2CSTR(password);
    dbref ref = create_player(name, pwd);
    return INT2FIX(ref);
}

static VALUE do_do_password(VALUE self, VALUE player_ref, VALUE old_pwd, VALUE new_pwd)
{
    (void) self;
    dbref player = FIX2INT(player_ref);
    const char* oldp = STR2CSTR(old_pwd);
    const char* newp = STR2CSTR(new_pwd);
    do_password(player, oldp, newp);
    return Qnil;
}

void Init_player()
{
	tinymud_module = rb_define_module("TinyMud");
    rb_define_method(tinymud_module, "do_notify", do_notify, 2);
    rb_define_method(tinymud_module, "do_emergency_shutdown", do_emergency_shutdown, 0);
	
    player_class = rb_define_class_under(tinymud_module, "Player", rb_cObject);
    rb_define_method(player_class, "lookup_player", do_lookup_player, 1);
    rb_define_method(player_class, "connect_player", do_connect_player, 2);
    rb_define_method(player_class, "create_player", do_create_player, 2);
    rb_define_method(player_class, "change_password", do_do_password, 3);
}
