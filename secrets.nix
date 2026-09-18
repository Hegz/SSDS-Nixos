{ config, ... }:
{
  # Secrets control
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.dbert-pass.neededForUsers = true;
  sops.secrets.wifi = {
    owner = "wpa_supplicant";
    group = "wpa_supplicant";
    mode = "0440";
  };

  sops.secrets."otto-authorized-keys" = { }; # root-readable; sshd's monitor process reads it before dropping privileges

  # Secret Management via sops-nix (Guacamole)
  sops.secrets.guac_admin_password = {
    # Ensure Tomcat/Guacamole user can read the decrypted secret
    owner = "tomcat";
  };

  # Render the user-mapping.xml securely in /run/secrets/ at boot
  sops.templates."guacamole-user-mapping.xml" = {
    owner = "tomcat";
    group = "tomcat";
    mode = "0600";

    content = ''
      <user-mapping>
        <authorize username="dbert" password="${config.sops.placeholder.guac_admin_password}">
          <connection name="Sway Desktop (wayvnc)">
            <protocol>vnc</protocol>
            <param name="hostname">127.0.0.1</param>
            <param name="port">5900</param>
          </connection>
        </authorize>
      </user-mapping>
    '';
  };
}
