rule FAMILY_variant
{
    meta:
        author      = "<analyst>"
        description = "<family> — <what this detects>"
        date        = "<YYYY-MM-DD>"
        hash        = "<sha256 of the sample>"
        reference   = "<session / report path>"
    strings:
        $s1 = "<unique decoded string / config marker>" ascii wide
        $code = { 6A ?? 68 ?? ?? ?? ?? E8 }   // <unique routine, e.g. the decryptor>
    condition:
        // PE: uint16(0)==0x5A4D ; ELF: uint32(0)==0x464C457F
        (uint16(0) == 0x5A4D or uint32(0) == 0x464C457F) and any of them
}
