;; 主配置文件，统一加载其他模块
(use-modules (gnu)
             (gnu system)
             (gnu packages)
             (srfi srfi-1)
             (ice-9 match))

(load "disk.scm")
(load "users.scm")
(load "packages.scm")

(operating-system
  (locale "en_US.utf8")
  (timezone "Asia/Hong_Kong")
  (keyboard-layout (keyboard-layout "us"))
  (host-name "o0o")

  (users user-config)
  (packages my-packages)
  (services (append my-services %base-services))
  (bootloader my-bootloader)
  (mapped-devices my-mapped-devices)
  (file-systems my-file-systems))
