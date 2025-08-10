;; 系统软件包和服务配置

(use-modules
  (gnu packages)
  (gnu services)
  (gnu services cups)
  (gnu services networking)
  (gnu services ssh)
  (gnu services xorg)
  (gnu services desktop)
  (gnu services base))

(define my-packages
  (append (list (specification->package "nss-certs"))
          %base-packages))

(define my-services
  (list
    (service openssh-service-type)
    (service network-manager-service-type)
    (service wpa-supplicant-service-type)
    (service ntp-service-type)
    (service gpm-service-type)
    (service cups-service-type)))
