package UnDead::Plugin;

use strict;
use MT::Template;

sub _param_edit_template {
    my ($cb, $app, $param, $tmpl) = @_;
    return unless ($param->{type} eq 'backup');
    my $blog = $app->blog
      or return;
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_template' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    return unless $param->{id};
    my $obj = MT->model('template')->load($param->{id})
      or return;
    (my $template_name = $obj->name) =~ s/\s\(Backup.*$//;
    (my $template_type = $obj->name) =~ s/^.*\d{2}:\d{2}:\d{2}\)\s//;
    my @templates = MT->model('template')->load({ type => $template_type,
                                              blog_id => $blog->id });
    my $templates = '';
    foreach my $template (@templates) {
        $templates .= '\'' . $template->name . '\', ';
    }
    $templates =~ s/,\s$//;
    my $require_outfile = '';
    $require_outfile = <<TEXT if ($template_type eq 'index');
            template_outfile: {
                required: '#restore_template:checked'
            }
TEXT
    my $plugin = MT->component("UnDead");
    my $message_required_name = $plugin->translate('Template Name is Required.');
    my $message_required_outfile = $plugin->translate('Outfile is Required for Index Template.');
    my $message_block_required_outfile = '';
    $message_block_required_outfile = <<TEXT if ($template_type eq 'index');
            template_outfile: {
                required: "$message_required_outfile",
            }
TEXT
    my $iefixer = ($template_type eq 'index') ? ',' : '';
    my $message_name_nooverwrap = $plugin->translate('Template Name is overwrapped.');

    my $newElement = $tmpl->createElement('app:setting', {
        id => 'restore_template',
        label => $plugin->translate('Restore Template'),
        label_class => 'no-header',
        required => 0 });
    my $innerHTML = <<TEXT;
<div>
    <__trans_section component="UnDead"><__trans phrase="Restore Template"></__trans_section>&nbsp;<input type="checkbox" name="restore_template" id="restore_template" value="1" />
</div>
<div id="input_restore">
  <div>
    <span><__trans phrase="Template Name">:</span>
    <input type="text" name="template_name" id="template_name" value="$template_name" />
  </div>
  <div>
    <__trans phrase="Template Type">:&nbsp;$template_type
  </div>
  <div>
    <span><__trans phrase="Output File">:</span>
    <input type="text" name="template_outfile" id="template_outfile" value="" />
  </div>
  <div>
    <span><__trans_section component="UnDead"><__trans phrase="Template Identifier"></__trans_section>:</span>
    <input type="text" name="template_identifier" id="template_identifier" />
  </div>
</div>
<style type="text/css">
#restore_template-field div {
    margin-bottom: 0.6em;
}
#restore_template-field div span {
    display: inline-block;
    width: 10em;
}
#input_restore input#template_name {
    width: 34em;
}
#input_restore input#template_outfile,
#input_restore input#template_identifier {
    width: 16em;
}
label.error {
    margin-left: 1em;
    color: #c00;
}
</style>
<script type="text/javascript">
var name_array = [ $templates ];
jQuery.validator.addMethod('namenooverwrap', function(value, element) {
    var name = jQuery('#template_name').val();
    var validate = true;
    jQuery.each(name_array, function() {
        if (this == name) {
            validate = false;
        }
    });
    return this.optional(element) || validate;
}, '$message_name_nooverwrap');
jQuery(document).ready(function(){
    jQuery('#input_restore').hide();
    var validator;
    jQuery('#restore_template').click(function() {
        if(jQuery(this).attr('checked') == true) {
            jQuery('#input_restore').show();
            validator = jQuery("#template-listing-form").validate({
                rules: {
                    template_name: {
                        required: '#restore_template:checked',
                        namenooverwrap: true
                    }$iefixer
$require_outfile
                },
                messages: {
                    template_name: {
                        required: "$message_required_name"
                    }$iefixer
$message_block_required_outfile
                }
            });
        } else {
            jQuery("#template-listing-form").data('validator', null);
            jQuery('#input_restore').hide();
            jQuery('#template_name').val('$template_name');
        }
    });
});
</script>
TEXT
    $newElement->innerHTML($innerHTML);
    my $oldElement = $tmpl->getElementById('linked_file');
    $tmpl->insertBefore($newElement, $oldElement);
}

sub _pre_save_template {
    my ($cb, $app, $obj) = @_;
    return 1 if ($obj->type ne 'backup');
    if ($app->param('restore_template')) {
        my $template_name = $app->param('template_name') || '';
        my $template_outfile = $app->param('template_outfile') || '';
        unless ($template_name) {
            ($template_name = $obj->name) =~ s/\s\(Backup.*$//;
        }
        (my $template_type = $obj->name) =~ s/^.*\d{2}:\d{2}:\d{2}\)\s//;
        if ($template_type eq 'index') {
            return 1 unless $template_outfile;
        }
        $obj->name($template_name);
        $obj->type($template_type);
        $obj->identifier($app->param('template_identifier')) if ($app->param('template_identifier'));
        $obj->outfile($template_outfile) if ($template_outfile);
    }
    1;
}

sub is_user_can {
    my ( $blog, $user, $permission ) = @_;
    $permission = 'can_' . $permission;
    my $perm = $user->is_superuser;
    unless ( $perm ) {
        if ( $blog ) {
            my $admin = 'can_administer_blog';
            $perm = $user->permissions( $blog->id )->$admin;
            $perm = $user->permissions( $blog->id )->$permission unless $perm;
        } else {
            $perm = $user->permissions()->$permission;
        }
    }
    return $perm;
}

sub doLog {
    my ($msg, $class) = @_;
    return unless defined($msg);

    require MT::Log;
    my $log = new MT::Log;
    $log->message($msg);
    $log->level(MT::Log::DEBUG());
    $log->class($class) if $class;
    $log->save or die $log->errstr;
}

1;
