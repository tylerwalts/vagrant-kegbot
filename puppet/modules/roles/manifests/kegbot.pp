class roles::kegbot {
    include kegbot::pre
    include kegbot::mysql
    include kegbot::server
}
