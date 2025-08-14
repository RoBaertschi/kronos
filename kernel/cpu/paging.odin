package kronos_cpu

// avl bits are not intepreted by the processor
Page_Map_Level_4_Entry :: bit_field u64 {
    present:         bool    | 1,
    read_write:      bool    | 1,
    user_supervisor: bool    | 1,
    write_through:   bool    | 1,
    cache_disable:   bool    | 1,
    accessed:        bool    | 1,
    _:               bool    | 3,
    avl0:            u8      | 3,
    address:         uintptr | 40,
    avl1:            u16     | 11,
    execute_disable: bool    | 1,
}

Page_Directory_Pointer_Entry :: bit_field u64 {
    present:         bool    | 1,
    read_write:      bool    | 1,
    user_supervisor: bool    | 1,
    write_through:   bool    | 1,
    cache_disable:   bool    | 1,
    accessed:        bool    | 1,
    _:               bool    | 3,
    avl1:            u8      | 3,
    address:         uintptr | 40,
    avl2:            u16     | 11,
    execute_disable: bool    | 1,
}

Page_Directory_Entry :: bit_field u64 {
    present:         bool    | 1,
    read_write:      bool    | 1,
    user_supervisor: bool    | 1,
    write_through:   bool    | 1,
    cache_disable:   bool    | 1,
    accessed:        bool    | 1,
    _:               bool    | 3,
    avl1:            u8      | 3,
    address:         uintptr | 40,
    avl2:            u16     | 11,
    execute_disable: bool    | 1,
}

Page_Table_Entry :: bit_field u64 {
    present:         bool    | 1,
    read_write:      bool    | 1,
    user_supervisor: bool    | 1,
    write_through:   bool    | 1,
    cache_disable:   bool    | 1,
    accessed:        bool    | 1,
    dirty:           bool    | 1,
    pat:             bool    | 1,
    global:          bool    | 1,
    avl1:            u8      | 3,
    address:         uintptr | 40,
    avl2:            u16     | 7,
    pk:              u8      | 4,
    execute_disable: bool    | 1,
}
