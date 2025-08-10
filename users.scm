;; 用户账户配置

(use-modules (gnu system shadow))

(define user-config
  (cons* (user-account
                  (name "Usra")
                  (comment "Test User")
                  (group "users")
                  (home-directory "/home/lu96")
                  (supplementary-groups '("wheel" "netdev" "audio" "video")))
                (user-account
                  (name "Userx")
                  (comment "Userx for X server daily use")
                  (group "users")
                  (home-directory "/home/lu96x")
                  (supplementary-groups '("netdev" "audio" "video")))
         %base-user-accounts))