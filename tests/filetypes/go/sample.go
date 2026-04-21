package main

import "time"

// Metadata demonstrates struct tags and basic types
type Metadata struct {
    ID        int64     `json:"id" check:"required"`
    CreatedAt time.Time `json:"created_at"`
    IsActive  bool      `json:"is_active"`
    Version   string    `json:"version"`
}

// UserProfile includes nested structs, pointers, and collections
type UserProfile struct {
    // 1. Embedded Struct (Named node: field_declaration)
    Metadata

    // 2. Basic pointers and strings
    Username *string `json:"username"`
    Email    string  `json:"email"`

    // 3. Collections: Slices and Maps
    Roles    []string          `json:"roles"`
    Settings map[string]string `json:"settings"`

    // 4. Nested Anonymous Struct
    Address struct {
        City    string `json:"city"`
        ZipCode int    `json:"zip_code"`
    } `json:"address"`

    // 5. Interface member (for polymorphism tests)
    Permissions any `json:"permissions"`

    // 6. Channel for concurrency tests
    StatusChan chan int `json:"-"`
}

// NewUserProfile is a constructor example to test return types
func NewUserProfile(name string) *UserProfile {
    return &UserProfile{
        Username: &name,
        Roles:    []string{"user", "guest"},
        Settings: make(map[string]string),
    }
}
