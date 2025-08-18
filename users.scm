;; 用户账户配置

(use-modules (gnu system shadow))

(define user-config
  (cons* (user-account
                  (name "Usera")
                  (comment "Test User")
                  (group "users")
                  (home-directory "/home/Usra")
                  (supplementary-groups '("wheel" "netdev" "audio" "video")))
                (user-account
                  (name "Userx")
                  (comment "Userx for X server daily use")
                  (group "users")
                  (home-directory "/home/Userx")
                  (supplementary-groups '("netdev" "audio" "video")))
         %base-user-accounts))
