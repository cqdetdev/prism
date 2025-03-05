package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
)

type security struct {
	key []byte
}

func newSecurity(key string) *security {
	return &security{
		key: []byte(key),
	}
}

func (s *security) encrypt(data []byte) (iv []byte, ciphertext []byte, tag []byte) {
	iv = make([]byte, 12)
	rand.Read(iv)

	block, err := aes.NewCipher(s.key)
	if err != nil {
		panic(err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		panic(err)
	}

	ciphertext = gcm.Seal(nil, iv, data, nil)
	tag = ciphertext[len(ciphertext)-gcm.Overhead():]
	ciphertext = ciphertext[:len(ciphertext)-gcm.Overhead()]

	return iv, ciphertext, tag
}

func (s *security) decrypt(iv, ciphertext, tag []byte) ([]byte, error) {
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	full := append(ciphertext, tag...)
	plaintext, err := gcm.Open(nil, iv, full, nil)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}
