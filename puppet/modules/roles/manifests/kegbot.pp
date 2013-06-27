class roles::kegbot {
    include base
    include kegbot::pre
    include kegbot::mysql
    include kegbot::server
}
