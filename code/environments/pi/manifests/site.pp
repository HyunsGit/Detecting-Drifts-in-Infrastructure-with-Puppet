$noop_mode = lookup('noop_mode', Boolean, 'first', false)
if $noop_mode {
  noop()
}

node default {
  include security_hardening
  include monitoring
  include networking
  include time
}
