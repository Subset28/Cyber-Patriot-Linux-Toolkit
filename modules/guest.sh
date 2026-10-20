# shellcheck shell=bash
# Guest login. Only LightDM is handled; other display managers are reported.

mod_guest() {
    say "Guest login"
    if [ "$DM" = lightdm ]; then
        act "disable LightDM guest session" sh -c 'mkdir -p /etc/lightdm/lightdm.conf.d && printf "[Seat:*]\nallow-guest=false\n" > /etc/lightdm/lightdm.conf.d/50-no-guest.conf'
    elif [ "$DM" = gdm3 ]; then
        echo "    display manager is gdm3 (Ubuntu's GNOME default). The LightDM guest rule does not apply. Check the GDM login settings by hand."
    else
        echo "    display manager is '${DM:-unknown}', not LightDM. Check its guest setting by hand."
    fi
}
