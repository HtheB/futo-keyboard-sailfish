package main

import (
	"encoding/json"
	"errors"
	"strings"
)

// Names and derivations follow ChineseIMESettings in the pinned FUTO source.
type compositionOptions struct {
	FlickOnly      bool   `json:"flickOnly"`
	HalfWidthSpace bool   `json:"halfWidthSpace"`
	PinyinScheme   string `json:"pinyinScheme"`
	OutputScript   string `json:"outputScript"`
	FuzzyPinyin    string `json:"fuzzyPinyin"`
	Correction     bool   `json:"correction"`
}

var doublePinyinSchemas = map[string]string{
	"FullPinyin": "", "Natural": "double_pinyin", "ABC": "double_pinyin_abc",
	"FlyPY": "double_pinyin_flypy", "MS": "double_pinyin_mspy",
	"PYJJ": "double_pinyin_pyjj", "ST": "double_pinyin_st",
}

var fuzzyPinyinDerivations = map[string][]string{
	"Z_ZH": {"derive/^z/zh/", "derive/^zh/z/"},
	"C_CH": {"derive/^c/ch/", "derive/^ch/c/"},
	"S_SH": {"derive/^s/sh/", "derive/^sh/s/"},
	"L_N":  {"derive/^l/n/", "derive/^n/l/"},
	"F_H":  {"derive/^f/h/", "derive/^h/f/"},
	"R_L":  {"derive/^r/l/"}, "K_G": {"derive/^k/g/"},
	"AN_ANG":   {"derive/an$/ang/", "derive/ang$/an/"},
	"EN_ENG":   {"derive/en$/eng/", "derive/eng$/en/"},
	"IN_ING":   {"derive/in$/ing/", "derive/ing$/in/"},
	"IAN_IANG": {"derive/ian$/iang/", "derive/iang$/ian/"},
	"UAN_UANG": {"derive/uan$/uang/", "derive/uang$/uan/"},
}

func parseCompositionOptions(raw string) (compositionOptions, error) {
	options := compositionOptions{PinyinScheme: "FullPinyin", OutputScript: "ByLanguage", Correction: true}
	if len(raw) > 2048 {
		return options, errors.New("invalid conversion options")
	}
	if err := json.Unmarshal([]byte(raw), &options); err != nil {
		return options, errors.New("invalid conversion options")
	}
	if _, ok := doublePinyinSchemas[options.PinyinScheme]; !ok {
		return options, errors.New("invalid Pinyin scheme")
	}
	if options.OutputScript != "ByLanguage" && options.OutputScript != "Simplified" && options.OutputScript != "Traditional" {
		return options, errors.New("invalid Chinese output script")
	}
	for _, mode := range strings.Split(options.FuzzyPinyin, ",") {
		if mode != "" {
			if _, ok := fuzzyPinyinDerivations[mode]; !ok {
				return options, errors.New("invalid fuzzy Pinyin option")
			}
		}
	}
	return options, nil
}

func (options compositionOptions) simplified(language string) bool {
	return options.OutputScript == "Simplified" || options.OutputScript != "Traditional" && language == "ZH"
}

func (options compositionOptions) mozcFlags() string {
	flags := "toggle"
	if options.FlickOnly {
		flags = "flick"
	}
	if options.HalfWidthSpace {
		flags += ",half"
	}
	return flags
}
